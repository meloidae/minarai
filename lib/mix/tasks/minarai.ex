defmodule Mix.Tasks.Minarai do
  def run(argv) do
    System.no_halt(true)
    {opts, _, _} = OptionParser.parse(argv,
      aliases: [b: :bootrom, c: :cart, s: :save_path],
      switches: [bootrom: :string, cart: :string, save_path: :string]
    )
    Minarai.start_link(opts)
  end
end
