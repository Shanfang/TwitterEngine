defmodule TwitterWeb.TwitterChannel do
  use TwitterWeb, :channel
  require Logger

  alias Twitter.Server
  
  def join("twitter", payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # Handle register account
  def handle_in("register_account", %{"userID" => userID}, socket) do 
    case Server.register_account(userID) do
      :ok ->
        Logger.info("A user is successfully registered with ID: #{userID}")
        {:noreply, socket}
      :duplicate ->  
        Logger.info("This username is already registered, please try another one.")
        # {:reply, {:ok, %{event: "register_account", error: "This user is already registered!"}}, socket}
        {:reply, {:ok, %{register_account: "register_account", userID: userID, error: "This user is already registered!"}}, socket}
    end
  end

  # # Handle send tweet 
  # def handle_in("send_tweet", %{"tweet" => tweet, "userID" => userID}, socket) do 
  #   Server.send_tweet(tweet, userID)
  #   {:noreply, socket}            
  # end

  # Handle re_tweet 
  def handle_in("re_tweet", %{"tweet" => tweet, "userID" => userID}, socket) do 
    Server.re_tweet(tweet, userID)
    {:noreply, socket}            
  end

  # Handle re_connect 
  def handle_in("re_connect", %{"userID" => userID}, socket) do 
    case Server.connect(userID) do
      {tweets, mentions} -> 
          Logger.info("Timeline for user:#{userID}")
          Enum.each(tweets, fn(tweet) -> IO.puts(tweet) end)
          Logger.info("\nTweets that mention user:#{userID}")
          Enum.each(mentions, fn(mention) -> IO.puts(mention) end)
          {:reply, {:ok, %{re_connect: "re_connect", userID: userID, tweets: tweets, mentions: mentions}}, socket}
      :error ->
          {:noreply, socket}
    end
  end

  # Handle subscribe
  def handle_in("subscribe", %{"to_subscribe_ID" => to_subscribe_ID, "userID" => userID}, socket) do
    case Server.subscribe(to_subscribe_ID, userID) do
      :ok ->
        Logger.info("Successfully subscribed!")
        {:noreply, socket}
      :error ->
        {:reply, {:ok, %{subscribe: "subscribe", userID: userID, error: "The user you are subscribing does not exist!"}}, socket}
    end
  end

  # Handle query tweet
  def handle_in("query", %{"query" => query, "userID" => userID}, socket) do
    result = Server.query_tweet(query, userID)
    IO.inspect result
    {:reply, {:ok, %{userID: userID, query: query, result: result}}, socket}           
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (tweet:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
