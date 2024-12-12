defmodule Oban.Web.SearchTest do
  use Oban.Web.Case, async: true

  alias Oban.Web.Search

  describe "append/2" do
    import Search, only: [append: 3]

    @known MapSet.new(~w(args. queues:))

    test "appending new qualifiers" do

      assert "queues:" == append("qu", "queues:", @known)
      assert "queues:" == append("queue", "queues:", @known)
      assert "queues:" == append("queue:", "queues:", @known)
      assert "args." == append("arg", "args.", @known)
    end

    test "preventing duplicate qualifier values" do
      assert "queues:" == append("queues:", "queues:", @known)
    end

    test "quoting terms with whitespace" do
      assert ~s(args.account:"A B C") == append("args.account:A", "A B C", @known)
      assert ~s(args.account:"A,B,C") == append("args.account:A", "A,B,C", @known)
    end
  end
end
