defmodule TwitterWeb.FollowingChannel do
  use TwitterWeb, :channel

  def join("following:" <> to_follow, payload, socket) do
    if authorized?(payload) do
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (following:lobby).
  def handle_in("new_tweet", %{"tweet" => tweet, "userID" => userID}, socket) do
    Server.send_tweet(tweet, userID)
    broadcast socket, "new_tweet", tweet
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
end
