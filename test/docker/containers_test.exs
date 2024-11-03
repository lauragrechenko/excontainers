defmodule Docker.ContainersTest do
  use ExUnit.Case, async: true

  alias Docker.{BindMount, CommandWaitStrategy, Container, Containers}
  import Support.DockerTestUtils

  @alpine "alpine:20201218"

  setup_all do
    pull_image(@alpine)
    :ok
  end

  describe "create" do
    test "creates a container with the specified config" do
      unique_container_name = "test_create_container_#{UUID.uuid4()}"

      config = %Container{
        image: @alpine,
        cmd: ["sleep", "infinity"],
        labels: %{"test-label-key" => "test-label-value"}
      }

      on_exit(fn -> remove_container(unique_container_name) end)

      {:ok, container_id} = Containers.create(config, unique_container_name)

      {container_info, _exit_code = 0} = System.cmd("docker", ~w(ps -a -f label=test-label-key=test-label-value))
      assert container_info =~ unique_container_name
      assert container_info =~ short_id(container_id)
    end

    test "supports mapping ports on the container to random ports on the host" do
      unique_container_name = "test_create_container_#{UUID.uuid4()}"

      config = %Container{
        image: @alpine,
        cmd: ["sleep", "infinity"],
        exposed_ports: ["1234/tcp"]
      }

      on_exit(fn -> remove_container(unique_container_name) end)

      {:ok, container_id} = Containers.create(config, unique_container_name)

      System.cmd("docker", ["start", container_id])
      {container_port, _exit_code = 0} = System.cmd("docker", ["port", container_id])
      assert container_port =~ "1234/tcp"
    end

    test "supports mapping ports on the container to specific ports on the host" do
      unique_container_name = "test_create_container_#{UUID.uuid4()}"

      config = %Container{
        image: @alpine,
        cmd: ["sleep", "infinity"],
        exposed_ports: ["1234/tcp": 8792]
      }

      on_exit(fn -> remove_container(unique_container_name) end)

      {:ok, container_id} = Containers.create(config, unique_container_name)

      System.cmd("docker", ["start", container_id])
      {container_port, _exit_code = 0} = System.cmd("docker", ["port", container_id])
      assert container_port =~ "1234/tcp -> 0.0.0.0:8792"
    end

    test "supports setting environment variables" do
      config = %Container{
        image: @alpine,
        cmd: ["sleep", "infinity"],
        environment: %{"TEST_VARIABLE" => "test value"}
      }

      {:ok, container_id} = Containers.create(config)
      on_exit(fn -> remove_container(container_id) end)

      System.cmd("docker", ["start", container_id])
      {stdout, _exit_code = 0} = System.cmd("docker", ["exec", container_id, "sh", "-c", "echo $TEST_VARIABLE"])
      assert stdout =~ "test value"
    end

    test "supports setting containers as privileged" do
      config = %Container{image: @alpine, privileged: true}

      {:ok, container_id} = Containers.create(config)

      {container_info, _exit_code = 0} = System.cmd("docker", ["inspect", container_id])
      assert container_info =~ ~s("Privileged": true)
    end

    test "supports bind mounting volumes" do
      config = %Container{
        image: @alpine,
        cmd: ["sleep", "infinity"],
        bind_mounts: [%BindMount{host_src: Path.expand("mix.exs"), container_dest: "/root/mix.exs"}]
      }

      {:ok, container_id} = Containers.create(config)
      on_exit(fn -> remove_container(container_id) end)

      System.cmd("docker", ["start", container_id])
      {ls_output, _exit_code = 0} = System.cmd("docker", ["exec", container_id, "ls", "/root/mix.exs"])
      assert ls_output =~ "mix.exs"
    end

    test "returns error when container configuration is invalid" do
      config = %Container{image: "invalid image"}

      assert {:error, _} = Containers.create(config)
    end
  end

  describe "run" do
    test "creates and starts a container with the given config" do
      container_config = %Container{image: @alpine, cmd: ["sleep", "infinity"]}

      {:ok, container_id} = Containers.run(container_config)
      on_exit(fn -> remove_container(container_id) end)

      assert container_running?(container_id)
    end

    test "waits for container to be ready according to the wait strategy" do
      container_config = %Container{
        image: @alpine,
        cmd: ["sh", "-c", "sleep 1 && touch /root/.ready && sleep infinity"],
        wait_strategy: CommandWaitStrategy.new(["ls", "/root/.ready"])
      }

      {:ok, container_id} = Containers.run(container_config)
      on_exit(fn -> remove_container(container_id) end)

      assert {_stdout, _exit_code = 0} = System.cmd("docker", ["exec", container_id, "ls", "/root/.ready"])
    end

    test "when image does not exist, automatically fetches it before starting the container" do
      image_that_no_one_should_be_using = "busybox:latest"

      container_config = %Container{
        image: image_that_no_one_should_be_using,
        cmd: ["sleep", "infinity"]
      }

      remove_image(image_that_no_one_should_be_using)
      refute image_exists?(image_that_no_one_should_be_using)

      {:ok, container_id} = Containers.run(container_config)
      on_exit(fn -> remove_container(container_id) end)

      assert image_exists?(image_that_no_one_should_be_using)
    end
  end

  describe "start" do
    test "starts a created container" do
      container_id = create_a_container()

      :ok = Containers.start(container_id)

      assert container_running?(container_id)
    end

    test "returns error when container does not exist" do
      assert {:error, _} = Containers.start("unexisting-container-#{UUID.uuid4()}")
    end
  end

  describe "stop" do
    test "stops a running container" do
      container_id = run_a_container()
      :ok = Containers.stop(container_id, timeout_seconds: 1)

      refute container_running?(container_id)
    end

    test "returns :ok and does nothing if container was already stopped" do
      container_id = create_a_container()
      :ok = Containers.stop(container_id)

      refute container_running?(container_id)
    end

    test "returns error when container does not exist" do
      assert {:error, _} = Containers.stop("unexisting-container-#{UUID.uuid4()}")
    end
  end
end
