defmodule Phauxth.New.Generator do
  @moduledoc false

  def check_directory do
    if Mix.Project.config() |> Keyword.fetch(:app) == :error do
      Mix.raise("Not in a Mix project. Please make sure you are in the correct directory.")
    end
  end

  def create_file(path, contents, create_backups) do
    if File.exists?(path) and create_backups do
      backup = path <> ".bak"
      Mix.shell().info([:green, "* creating ", :reset, Path.relative_to_cwd(backup)])
      File.rename(path, backup)
    end

    Mix.shell().info([:green, "* creating ", :reset, Path.relative_to_cwd(path)])
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, contents)
  end

  def base_name do
    Mix.Project.config() |> Keyword.fetch!(:app) |> to_string
  end

  def update_mix(confirm) do
    entry = mix_input(confirm) |> EEx.eval_string()
    {:ok, mixfile} = File.read("mix.exs")
    new_mix = String.replace(mixfile, ~r/{:cowboy, "~> \d\.\d+"}/, entry <> "      \\0")
    File.write("mix.exs", new_mix)
  end

  def update_config(confirm, base_name, base) do
    entry =
      config_input(confirm, base_name, base)
      |> EEx.eval_string(endpoint: inspect(get_endpoint(base_name)))

    {:ok, conf} = File.read("config/config.exs")
    new_conf = String.replace(conf, ~r/# Configures Elixir's Logger/, entry <> "\\0")
    File.write("config/config.exs", new_conf)

    test_entry = test_config_input(confirm, base_name, base)
    {:ok, test_conf} = File.read("config/test.exs")
    File.write("config/test.exs", test_conf <> test_entry)
  end

  def timestamp do
    {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
    "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
  end

  def confirm_deps_message(true) do
    """
    bamboo has been added to the mix.exs file as a dependency.
    If you want to use a different library to email users, edit
    the mix.exs file.

    Run `mix deps.get`.
    """
  end

  def confirm_deps_message(_), do: "Run `mix deps.get`."

  defp get_endpoint(base_name) do
    web = base_name <> "_web"

    Macro.camelize(web)
    |> Module.concat(Endpoint)
  end

  defp gen_token_salt(length) do
    :crypto.strong_rand_bytes(length) |> Base.encode64() |> binary_part(0, length)
  end

  defp mix_input(false) do
    "{:phauxth, \"~> 1.2\"},\n" <> "      {:bcrypt_elixir, \"~> 1.0\"},\n"
  end

  defp mix_input(true) do
    mix_input(false) <> "      {:bamboo, \"~> 0.8\"},\n"
  end

  defp config_input(false, _, _) do
    """
    # Phauxth authentication configuration
    config :phauxth,
      token_salt: \"#{gen_token_salt(8)}\",
      endpoint: <%= endpoint %>\n
    """
  end

  defp config_input(true, base_name, base) do
    config_input(false, base_name, base) <>
      """
      # Mailer configuration
      config :#{base_name}, #{base}.Mailer,
        adapter: Bamboo.LocalAdapter\n
      """
  end

  defp test_config_input(false, _, _) do
    """
    \n\n# Comeonin password hashing test config
    #config :argon2_elixir,
      #t_cost: 2,
      #m_cost: 8
    config :bcrypt_elixir, log_rounds: 4
    #config :pbkdf2_elixir, rounds: 1
    """
  end

  defp test_config_input(true, base_name, base) do
    test_config_input(false, base_name, base) <>
      """
      \n# Mailer test configuration
      config :#{base_name}, #{base}.Mailer,
        adapter: Bamboo.TestAdapter
      """
  end

  defp pad(i) when i < 10, do: <<?0, ?0 + i>>
  defp pad(i), do: to_string(i)
end
