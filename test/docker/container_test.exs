defmodule Docker.ContainerTest do
  use ExUnit.Case, async: true

  alias Docker.{BindMount, CommandWaitStrategy, Container}

  describe "new/2" do
    test "creates container with given image" do
      assert Container.new("some-image") == %Docker.Container{image: "some-image"}
    end

    test "when exposing ports, exposes them for TCP by default" do
      container_config = Container.new("any", exposed_ports: [1111, "2222/udp"])
      assert container_config.exposed_ports == ["1111/tcp", "2222/udp"]
    end

    test "can customize container properties" do
      container_config =
        Container.new(
          "any",
          bind_mounts: [BindMount.new("/host/src", "/container/dest", "ro")],
          cmd: ~w(echo hello),
          environment: %{"ENV_KEY" => "ENV_VALUE"},
          exposed_ports: ["1111/tcp"],
          privileged: true,
          wait_strategy: CommandWaitStrategy.new(["my", "cmd"])
        )

      assert container_config == %Container{
               image: "any",
               bind_mounts: [%BindMount{host_src: "/host/src", container_dest: "/container/dest", options: "ro"}],
               cmd: ~w(echo hello),
               environment: %{"ENV_KEY" => "ENV_VALUE"},
               exposed_ports: ["1111/tcp"],
               privileged: true,
               wait_strategy: %CommandWaitStrategy{command: ["my", "cmd"]}
             }
    end
  end
end
