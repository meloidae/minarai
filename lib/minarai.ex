defmodule Minarai do
  @behaviour :wx_object
  import Bitwise
  alias Gameboy.Utils

  @title 'Minarai'
  @width 160
  @height 144
  @scale 4
  # @size {@width * @scale, @height * @scale}
  @save_path "state.save"
  @color {<<0xe0, 0xf0, 0xe7>>, <<0x8b, 0xa3, 0x94>>, <<0x55, 0x64, 0x5a>>, <<0x34, 0x3d, 0x37>>}

  #######
  # API #
  #######
  def start_link(opts \\ []) do
    window = :wx_object.start_link(__MODULE__, opts, [])
    pid = :wx_object.get_pid(window)
    Process.register(pid, __MODULE__)
  end

  #################################
  # :wx_object behavior callbacks #
  #################################
  def init(opts) do
    :persistent_term.put({Minarai, :ui_pid}, self())
    save_path = case Access.fetch(opts, :save_path) do
      {:ok, path} ->
        path
      _ ->
        @save_path
    end
    case opts[:record_stats] do
      true ->
        :persistent_term.put({Minarai, :record_stats}, true)
      _ ->
        nil
    end
    scale = case opts[:scale] do
      scale when is_integer(scale) ->
        scale
      _ ->
        @scale
    end

    size = {@width * scale, @height * scale}


    wx = :wx.new([])
    frame = :wxFrame.new(wx, :wx_const.id_any, @title, [{:size, size}])
    :wxWindow.connect(frame, :close_window)
    :wxFrame.show(frame)

    gl_attrib = [{:attribList, [:wx_const.gl_rgba,
                                :wx_const.gl_doublebuffer,
                                :wx_const.gl_min_red, 8,
                                :wx_const.gl_min_green, 8,
                                :wx_const.gl_min_blue, 8,
                                :wx_const.gl_depth_size, 24, 0]}]
    canvas = :wxGLCanvas.new(frame, [size: size] ++ gl_attrib)
    ctx = :wxGLContext.new(canvas)

    :wxGLCanvas.connect(canvas, :size)
    :wxWindow.reparent(canvas, frame)
    :wxGLCanvas.setCurrent(canvas, ctx)
    :wxFrame.connect(canvas, :key_down)
    :wxFrame.connect(canvas, :key_up)
    setup_gl(canvas)
    buffer = generate_binary()
    :gl.enable(:gl_const.texture_2d)
    texture = load_texture(buffer)

    keys = %{start: false, select: false, b: false, a: false, down: false, up: false, left: false, right: false}

    :ets.new(:gb_process, [:set, :public, :named_table])

    Utils.compile_template("templates/bootrom_template.ex", {"path", opts[:bootrom]})
    Utils.compile_template("templates/cartridge_template.ex", {"path", opts[:cart]})
    gb = Gameboy.init(opts)
    spawn_opt = [:link, min_heap_size: 2000]
    pid = Process.spawn(fn -> Gameboy.start_chain(gb) end, spawn_opt)
    :ets.insert(:gb_process, {:logic_pid, pid})
    :ets.insert(:gb_process, {:ui_pid, self()})

    state = %{
      frame: frame,
      canvas: canvas,
      scale: scale,
      texture: texture,
      buffer: buffer,
      prev_time: nil,
      fps: [],
      keys: keys,
      save_path: save_path,
    }

    # :erlang.trace(pid, true, [:garbage_collection, tracer: self()])
    # :erlang.trace(next_pid, true, [:garbage_collection, tracer: self()])

    {frame, state}
  end

  def code_change(_, _, state) do
    {:stop, :not_implemented, state}
  end

  def handle_cast(msg, state) do
    IO.puts "Cast:"
    IO.inspect msg
    {:noreply, state}
  end

  def handle_call(msg, _from, state) do
    IO.puts "Call:"
    IO.inspect msg
    {:reply, :ok, state}
  end

  def handle_info(:stop, state) do
    :wxGLCanvas.destroy(state.canvas)
    {:stop, :normal, state}
  end

  def handle_info({:trace, _pid, flag, info}, state) do
    if flag == :gc_major_start do
      count = Process.get(:gc_major_count)
      count = if count == nil, do: 1, else: count + 1
      IO.puts("#{flag} = #{count}")
      if :ets.whereis(:stats_table) != :undefined do
        case :ets.lookup(:stats_table, :counter) do
          [{:counter, index} | _] -> IO.puts("frame = #{index}")
          _ -> nil
        end
      end
      Process.put(:gc_major_count, count)
    end
    {:noreply, state}
  end

  def handle_info({:change_pid, pid}, state) do
    {:noreply, %{state | pid: pid}}
  end

  def handle_info({:update, buffer}, %{frame: frame, prev_time: prev_time, fps: fps_stats} = state) do
    curr_time = System.monotonic_time()
    fps_stats = if !is_nil(prev_time) do
      diff = System.convert_time_unit(curr_time - prev_time, :native, :microsecond)
      fps = 1_000_000 / diff
      :wxTopLevelWindow.setTitle(frame, "#{@title} [FPS: #{Float.round(fps, 2)}]")
      [fps | fps_stats]
    else
      []
    end
    state = %{state | buffer: buffer, prev_time: curr_time, fps: fps_stats}
    :wx.batch(fn -> render(state) end)
    {:noreply, state}
  end

  def handle_info({:update_screen, pixels}, %{frame: frame, prev_time: prev_time, fps: fps_stats} = state) do
    curr_time = System.monotonic_time()
    fps_stats = if !is_nil(prev_time) do
      diff = System.convert_time_unit(curr_time - prev_time, :native, :microsecond)
      fps = 1_000_000 / diff
      :wxTopLevelWindow.setTitle(frame, "#{@title} [FPS: #{Float.round(fps, 2)}]")
      [fps | fps_stats]
    else
      []
    end
    buffer = map_pixel_to_color(pixels)
    state = %{state | buffer: buffer, prev_time: curr_time, fps: fps_stats}
    :wx.batch(fn -> render(state) end)
    {:noreply, state}
  end

  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
    {:stop, :normal, state}
  end

  def handle_event({:wx, _, _, _, {:wxSize, :size, {width, height}, _}}, state) do
    if width != 0 and height != 0 do
      resize_gl_scene(width, height)
    end
    {:noreply, state}
  end

  @enter 13
  def handle_event({:wx, _, _, _,
    {:wxKey, :key_down, _x, _y, @enter, _ctrl, _shift, _alt, _meta, _uni_char, _raw_code, _raw_flags}
  }, state) do
    # pid = state.pid
    pid = :ets.lookup_element(:gb_process, :logic_pid, 2)
    send(pid, :step)
    {:noreply, state}
  end

  # Save state: s key
  def handle_event({:wx, _, _, _,
    {:wxKey, :key_down, _x, _y, ?S, true, _shift, _alt, _meta, _uni_char, _raw_code, _raw_flags}
  }, %{save_path: path} = state) do
    # pid = state.pid
    pid = :ets.lookup_element(:gb_process, :logic_pid, 2)
    send(pid, {:save, path})
    {:noreply, state}
  end

  # Load state: l key
  def handle_event({:wx, _, _, _,
    {:wxKey, :key_down, _x, _y, ?L, true, _shift, _alt, _meta, _uni_char, _raw_code, _raw_flags}
  }, %{save_path: path} = state) do
    # pid = state.pid
    pid = :ets.lookup_element(:gb_process, :logic_pid, 2)
    send(pid, {:load, path})
    {:noreply, state}
  end

  # Log fps stats
  def handle_event({:wx, _, _, _,
    {:wxKey, :key_down, _x, _y, ?F, true, _shift, _alt, _meta, _uni_char, _raw_code, _raw_flags}
  }, state) do
    # pid = state.pid
    pid = :ets.lookup_element(:gb_process, :logic_pid, 2)
    # Log fps stats to file
    # fps_output = fps_stats
    #          |> Enum.reverse()
    #          |> Stream.with_index()
    #          |> Enum.map(fn {fps, i} -> "#{i + 1},#{fps}\n" end)
    #          |> IO.iodata_to_binary()
    # File.open("log/fps.csv", [:write], fn file ->
    #   IO.write(file, "frame,fps\n")
    #   IO.write(file, fps_output)
    # end)
    # IO.puts("Wrote fps stats to: log/fps.csv")
    send(pid, {:save_latency, "log/stats.csv"})
    # Clear fps stats
    {:noreply, state}
  end

  # Game controls
  # A: z key
  # B: x key
  # Start: c key
  # Select: v key
  key_names = [:start, :select, :b, :a, :down, :up, :left, :right]
  key_codes = [?C, ?V, ?X, ?Z, 317, 315, 314, 316]
  for {name, code} <- Enum.zip([key_names, key_codes]) do
    def handle_event({:wx, _, _, _,
      {:wxKey, :key_down, _x, _y, unquote(code), _ctrl, _shift, _alt, _meta, _uni_char, _raw_code, _raw_flags}
    }, %{keys: %{unquote(name) => pressed} = keys} = state) do
      # pid = state.pid
      pid = :ets.lookup_element(:gb_process, :logic_pid, 2)
      if !pressed do
        send(pid, {:key_down, unquote(name)})
        Map.put(keys, unquote(name), true)
      else
        keys
      end
      {:noreply, %{state | keys: keys}}
    end
  end
  for {name, code} <- Enum.zip([key_names, key_codes]) do
    def handle_event({:wx, _, _, _,
      {:wxKey, :key_up, _x, _y, unquote(code), _ctrl, _shift, _alt, _meta, _uni_char, _raw_code, _raw_flags}
    }, %{keys: keys} = state) do
      # pid = state.pid
      pid = :ets.lookup_element(:gb_process, :logic_pid, 2)
      send(pid, {:key_up, unquote(name)})
      {:noreply, %{state | keys: Map.put(keys, unquote(name), false)}}
    end
  end

  def handle_event({:wx, _, _, _, _} = msg, state) do
    IO.puts("#{inspect(msg)}")
    {:noreply, state}
  end


  def terminate(_reason, state) do
    :wxGLCanvas.destroy(state.canvas)
  end


  defp generate_binary() do
    1..@width * @height
    |> Enum.reduce(<<>>, fn _, acc ->
      acc <> <<155, 188, 15>>
    end)
  end

  defp load_texture(buffer) do
    # Generate texture id
    [tex_id | _] = :gl.genTextures(1)

    # Send texture to gp
    :gl.pixelStorei(:gl_const.unpack_alignment, 1)
    :gl.bindTexture(:gl_const.texture_2d, tex_id)
    # Configure texture
    :gl.texParameteri(:gl_const.texture_2d, :gl_const.texutre_mag_filter, :gl_const.nearest)
    :gl.texParameteri(:gl_const.texture_2d, :gl_const.texutre_min_filter, :gl_const.nearest)
    :gl.texImage2D(:gl_const.texture_2d,
      0,
      :gl_const.rgb,
      @width,
      @height,
      0,
      :gl_const.rgb,
      :gl_const.unsigned_byte,
      buffer)

    w = power_of_two_roof(@width)
    h = power_of_two_roof(@height)

    %{tex_id: tex_id, w: @width, h: @height, minx: 0.0, miny: 0.0, maxx: @width / w, maxy: @height / h}
  end
  
  defp setup_gl(win) do
    {w, h} = :wxWindow.getClientSize(win)
    resize_gl_scene(w, h)
    #:gl.shadeModel(:gl_const.smooth)
    :gl.clearColor(0.0, 0.0, 0.0, 0.0)
    # :gl.clearDepth(1.0)
    # :gl.depthFunc(:gl_const.lequal)
    # :gl.enable(:gl_const.depth_test)
    # :gl.depthFunc(:gl_const.lequal)
    # :gl.hint(:gl_const.perspective_correction_hint, :gl_const.nicest)
    setup_gl_2d(win)
    :ok
  end

  defp setup_gl_2d(win) do
    {w, h} = :wxWindow.getClientSize(win)

    # Note, there may be other things you need to change,
    # depending on how you have your OpenGL state set up.
    :gl.pushAttrib(:gl_const.enable_bit)
    :gl.disable(:gl_const.depth_test)
    :gl.disable(:gl_const.cull_face)
    :gl.enable(:gl_const.texture_2d)

    # This allows alpha blending of 2D textures with the scene
    # gl:enable(?GL_BLEND),
    # gl:blendFunc(?GL_SRC_ALPHA, ?GL_ONE_MINUS_SRC_ALPHA),

    :gl.matrixMode(:gl_const.projection)
    :gl.pushMatrix()
    :gl.loadIdentity()

    # SDL coordinates will be upside-down in the OpenGL world.  We'll
    # therefore flip the bottom and top coordinates in the orthogonal
    # projection to correct this.  
    # Note: We could flip the texture/image itself, but this will
    # also work for mouse coordinates.
    :gl.ortho(0.0, w / 1, h / 1, 0.0, 0.0, 1.0)

    :gl.matrixMode(:gl_const.modelview)
    :gl.pushMatrix()
    # :gl.loadIdentity()
    :ok
  end

  defp resize_gl_scene(width, height) do
    :gl.viewport(0, 0, width, height)
    :gl.matrixMode(:gl_const.projection)
    :gl.loadIdentity()
    :gl.ortho(0.0, width / 1, height / 1, 0.0, 0.0, 1.0)
    # :glu.perspective(45.0, width / height, 0.1, 100.0)
    :gl.matrixMode(:gl_const.modelview)
    :gl.loadIdentity()
    :ok
  end

  defp draw_texture(x, y, scale, %{tex_id: tex_id, w: w, h: h}) do
    :gl.clear(Bitwise.bor(:gl_const.color_buffer_bit, :gl_const.depth_buffer_bit))
    :gl.loadIdentity()
    :gl.bindTexture(:gl_const.texture_2d, tex_id)
    :gl.scalef(scale / 0.5, scale / 0.5, 0.0)
    :gl.begin(:gl_const.triangle_strip)
    :gl.texCoord2f(0.0, 0.0)
    :gl.vertex2i(x, y)
    :gl.texCoord2f(1.0, 0.0)
    :gl.vertex2i(x + div(w, 2), y)
    :gl.texCoord2f(0.0, 1.0)
    :gl.vertex2i(x, y + div(h, 2))
    :gl.texCoord2f(1.0, 1.0)
    :gl.vertex2i(x + div(w, 2), y + div(h, 2))
    :gl.end()
    :ok
  end

  defp draw_buffer(scale, fbo_id, %{tex_id: tex_id, w: w, h: h}) do
  end


  defp render(%{canvas: canvas, texture: texture, scale: scale, buffer: buffer} = _state) do
    # Update texture with new screen buffer
    :gl.texSubImage2D(:gl_const.texture_2d, 0,
      0, 0,
      @width, @height,
      :gl_const.rgb,
      :gl_const.unsigned_byte,
      buffer)
    draw_texture(0, 0, scale, texture)
    :wxGLCanvas.swapBuffers(canvas)
    :ok
  end

  defp map_pixel_to_color(pixels) do
    map_pixel_to_color(pixels, <<>>)
  end
  defp map_pixel_to_color(<<>>, acc), do: IO.iodata_to_binary(acc)
  defp map_pixel_to_color(<<p, rest::binary>>, acc) do
    map_pixel_to_color(rest, [acc | elem(@color, p)])
  end

  defp power_of_two_roof(x, n \\ 1)
  defp power_of_two_roof(x, n) when n >= x, do: n
  defp power_of_two_roof(x, n), do: power_of_two_roof(x, n * 2)
end
