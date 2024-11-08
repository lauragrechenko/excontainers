import Config

config :excontainers, docker_api_version: System.get_env("TEST_REMOTE_DOCKER_API_VER", "1.42")
