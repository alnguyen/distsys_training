defmodule Shortener.Router do
  use Plug.Router

  require Logger

  alias Plug.Conn
  alias Shortener.{
    Aggregates,
    LinkManager,
    Storage,
  }

  plug Plug.Logger, log: :debug
  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["text/*"]
  plug :match
  plug :dispatch

  post "/" do
    %{"url" => url} = conn.params

    case LinkManager.create(url) do
      {:ok, short_code} ->
        conn
        |> put_resp_header("location", short_link(conn, short_code))
        |> send_resp(201, short_code)

      {:error, _} ->
        conn
        |> send_resp(422, "Unable to shorten #{url}")
    end
  end

  get "/:short_code" do
    LinkManager.remote_lookup(short_code)
    |> handle_response(short_code, conn)
  end

  get "/:short_code/aggregates" do
    count = Aggregates.count_for(short_code)

    conn
    |> send_resp(200, "Redirects: #{count}")
  end

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp handle_response({:ok, url}, _, conn) do
    conn
    |> put_resp_header("location", url)
    |> send_resp(302, url)
  end

  defp handle_response({:error, :not_found}, _, conn) do
    send_resp(conn, 404, "Not Found")
  end

  defp handle_response({:error, :node_down}, short_code, conn) do
    Storage.get(short_code)
    |> handle_response(short_code, conn)
  end

  defp short_link(conn, code) do
    conn
    |> Conn.request_url
    |> URI.merge(code)
    |> to_string
  end
end
