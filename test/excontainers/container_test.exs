defmodule Excontainers.ContainerTest do
  use ExUnit.Case, async: true

  import Support.DockerTestUtils
  alias Excontainers.Container

  @sample_container_config Docker.Container.new("alpine:20201218", cmd: ["sleep", "infinity"])

  test "starts a container" do
    {:ok, pid} = Container.start_link(@sample_container_config)
    container_id = Container.container_id(pid)

    on_exit(fn -> remove_container(container_id) end)

    assert container_running?(container_id)
  end

  test "when terminating it stops a container" do
    {:ok, pid} = Container.start_link(@sample_container_config)
    container_id = Container.container_id(pid)

    Container.stop(container_id, %{stop_timeout: 5})

    refute container_running?(container_id)
  end

  test "stores the id of the corresponding docker container, when running" do
    {:ok, pid} = Container.start_link(@sample_container_config)

    container_id = Container.container_id(pid)
    on_exit(fn -> remove_container(container_id) end)
    assert Container.container_id(pid) == container_id
  end
end
