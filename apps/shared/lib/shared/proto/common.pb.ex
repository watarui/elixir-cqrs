defmodule ElixirCqrs.Common do
  @moduledoc """
  共通 Proto メッセージの定義
  """

  defmodule Error do
    @enforce_keys [:code, :message]
    defstruct [:code, :message, :details]

    @type t :: %__MODULE__{
            code: String.t(),
            message: String.t(),
            details: map() | nil
          }

    def new(code, message, details \\ %{}) do
      %__MODULE__{
        code: code,
        message: message,
        details: details
      }
    end
  end

  defmodule Result do
    @enforce_keys [:success]
    defstruct [:success, :message, :error]

    @type t :: %__MODULE__{
            success: boolean(),
            message: String.t() | nil,
            error: Error.t() | nil
          }

    def success(message \\ nil) do
      %__MODULE__{
        success: true,
        message: message,
        error: nil
      }
    end

    def failure(error) do
      %__MODULE__{
        success: false,
        message: nil,
        error: error
      }
    end
  end

  defmodule Pagination do
    defstruct limit: 20, offset: 0

    @type t :: %__MODULE__{
            limit: integer(),
            offset: integer()
          }
  end

  defmodule Sort do
    defstruct field: "name", order: :asc

    @type t :: %__MODULE__{
            field: String.t(),
            order: :asc | :desc
          }
  end

  defmodule Timestamp do
    defstruct [:seconds, :nanos]

    @type t :: %__MODULE__{
            seconds: integer(),
            nanos: integer()
          }

    def from_datetime(%DateTime{} = dt) do
      unix = DateTime.to_unix(dt, :second)
      nanos = dt.microsecond |> elem(0) |> Kernel.*(1000)

      %__MODULE__{
        seconds: unix,
        nanos: nanos
      }
    end

    def to_datetime(%__MODULE__{seconds: seconds, nanos: nanos}) do
      {:ok, dt} = DateTime.from_unix(seconds)
      microsecond = div(nanos, 1000)

      %{dt | microsecond: {microsecond, 6}}
    end
  end
end
