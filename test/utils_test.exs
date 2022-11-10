defmodule UtilsTest do
  use ExUnit.Case
  alias Gameboy.Utils

  test "is_plain_string" do
    assert Utils.is_plain_string(~S/"foo bar"/)
    assert not Utils.is_plain_string("foo bar")
    assert_raise TokenMissingError, fn -> Utils.is_plain_string("@@@@") end
    assert_raise SyntaxError, fn -> Utils.is_plain_string("foo b@r") end
  end
end
