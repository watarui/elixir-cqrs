#!/bin/sh

echo "Starting Client Service..."

cd apps/client_service

export ERL_AFLAGS="-elixir ansi_enabled true"

echo "Starting Phoenix server..."
mix phx.server