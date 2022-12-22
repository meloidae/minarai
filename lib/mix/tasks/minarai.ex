defmodule Mix.Tasks.Minarai do
  def run(argv) do
    System.no_halt(true)
    {opts, _, _} = OptionParser.parse(argv,
      aliases: [b: :bootrom, c: :cart, s: :save_path, r: :record_stats, f: :count_fn_calls],
      switches: [
        bootrom: :string, cart: :string, save_path: :string, 
        record_stats: :boolean, scale: :integer, count_fn_calls: :boolean
      ]
    )
    Minarai.start_link(opts)
  end
end
