defmodule Mix.Tasks.Minarai do
  def run(argv) do
    System.no_halt(true)
    {opts, _, _} = OptionParser.parse(argv,
      aliases: [b: :bootrom, c: :cart],
      switches: [bootrom: :string, cart: :string]
    )
    Minarai.start_link(opts)
  end
end
