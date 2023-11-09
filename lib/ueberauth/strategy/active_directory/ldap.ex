defmodule Ueberauth.Strategy.ActiveDirectory.Ldap do
  def connect do
    opts = Application.get_env(:ueberauth, Ueberauth.Strategy.ActiveDirectory.Ldap)
    # server = Dict.get(opts, :server)
    # port = Dict.get(opts, :port)
    # ssl = Dict.get(opts, :ssl)
    # user_dn = Dict.get(opts, :user_dn)
    # password = Dict.get(opts, :password)
    Exldap.connect(opts[:server], opts[:port], opts[:ssl], opts[:user_dn], opts[:password])
  end

  def close(conn) do
    Exldap.close(conn)
  end

  def authenticate(conn, username, password) do
    case get_attribute(conn, username, "distinguishedName") do
      {:ok, user_dn} ->
        case Exldap.verify_credentials(conn, user_dn, password) do
          :ok ->
            {:ok, get_user_attributes(conn, username)}

          _ ->
            {:error, :invalidCredentials}
        end

      {:error, :invalidCredentials} ->
        {:error, "Bind account username or password is invalid"}

      {:error, reason} ->
        {:error, "Failed to verify credentials: #{reason}"}
    end
  end

  def first_result(nil), do: nil
  def first_result(results), do: results |> List.first()

  defp get_user_attributes(conn, username) do
    case get_all_attributes(conn, username) do
      {:ok, user_entry} -> map_attributes(user_entry)
      {:error, error} -> {:error, error}
    end
  end

  defp get_attribute(%Exldap.Entry{} = entry, attribute) do
    attributes = map_attributes(entry)
    attributes[to_charlist(attribute)]
  end

  defp get_attribute(conn, username, attribute) do
    base_dn =
      Application.get_env(:ueberauth, Ueberauth.Strategy.ActiveDirectory.Ldap)[:base]

    case Exldap.search_field(conn, base_dn, "sAMAccountName", username) do
      {:ok, []} ->
        {:error, "User not found"}

      {:ok, results} ->
        user_dn = first_result(results) |> get_attribute(attribute) |> first_result
        {:ok, user_dn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_all_attributes(conn, username) do
    # |> Dict.get(:base)
    base_dn =
      Application.get_env(:ueberauth, Ueberauth.Strategy.ActiveDirectory.Ldap)[:base]

    case Exldap.search_field(conn, base_dn, "sAMAccountName", username) do
      {:ok, results} -> {:ok, first_result(results)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp map_attributes(entry), do: Enum.into(entry.attributes, %{})
end
