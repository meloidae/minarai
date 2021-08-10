defmodule Minarai do
  @behaviour :wx_object
  use Bitwise

  @title 'Elixir OpenGL'
  @width 160
  @height 144
  @scale 4
  @size {@width * @scale, @height * @scale}

  #######
  # API #
  #######
  def start_link() do
    window = :wx_object.start_link(__MODULE__, [], [])
    pid = :wx_object.get_pid(window)
    Process.register(pid, __MODULE__)
  end

  #################################
  # :wx_object behavior callbacks #
  #################################
  def init(config) do
    wx = :wx.new(config)
    frame = :wxFrame.new(wx, :wx_const.wx_id_any, @title, [{:size, @size}])
    :wxWindow.connect(frame, :close_window)
    :wxFrame.show(frame)

    opts = [{:size, @size}]
    gl_attrib = [{:attribList, [:wx_const.wx_gl_rgba,
                                :wx_const.wx_gl_doublebuffer,
                                :wx_const.wx_gl_min_red, 8,
                                :wx_const.wx_gl_min_green, 8,
                                :wx_const.wx_gl_min_blue, 8,
                                :wx_const.wx_gl_depth_size, 24, 0]}]
    canvas = :wxGLCanvas.new(frame, opts ++ gl_attrib)
    ctx = :wxGLContext.new(canvas)

    :wxGLCanvas.connect(canvas, :size)
    :wxWindow.reparent(canvas, frame)
    :wxGLCanvas.setCurrent(canvas, ctx)
    setup_gl(canvas)
    buffer = generate_binary()
    :gl.enable(:gl_const.gl_texture_2d)
    texture = load_texture(buffer)

    # Periodically send a message to trigger a redraw of the scene
    # timer = :timer.send_interval(trunc(1_000 / 59.73), self(), :update)
    # timer = :timer.send_interval(10, self(), :update)
    state = %{
      canvas: canvas,
      # timer: timer,
      texture: texture,
      buffer: buffer,
      pid: spawn_link(fn -> Gameboy.debug_start() end),
      count: 0.0,
      prev_time: nil,
      fps: nil,
    }

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
    # :timer.cancel(state.timer)
    :wxGLCanvas.destroy(state.canvas)
    {:stop, :normal, state}
  end

  # def handle_info(:update, state) do
  #   state = Map.put(state, :buffer, modify_binary(state.buffer))
  #   :wx.batch(fn -> render(state) end)
  #   state = %{state | count: state.count + 1}
  #   {:noreply, state}
  # end

  def handle_info({:update, buffer}, state) do
    curr_time = System.monotonic_time()
    fps = if !is_nil(state.prev_time) do
      diff = System.convert_time_unit(curr_time - state.prev_time, :native, :microsecond)
      1_000_000 / diff
    else
      nil
    end
    state = %{state | buffer: buffer, prev_time: curr_time, fps: fps}
    :wx.batch(fn -> render(state) end)
    {:noreply, state}
  end


  # Example input:
  # {:wx, -2006, {:wx_ref, 35, :wxFrame, []}, [], {:wxClose, :close_window}}
  def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
    {:stop, :normal, state}
  end

  def handle_event({:wx, _, _, _, {:wxSize, :size, {width, height}, _}}, state) do
    if width != 0 and height != 0 do
      resize_gl_scene(width, height)
    end
    {:noreply, state}
  end

  def terminate(_reason, state) do
    :wxGLCanvas.destroy(state.canvas)
    # :timer.cancel(state.timer)
    # :timer.sleep(300)
  end


  #####################
  # Private Functions #
  #####################
  
  defp generate_binary() do
    1..@width * @height
    |> Enum.reduce(<<>>, fn _, acc ->
      acc <> <<155, 188, 15>>
    end)
  end

  defp modify_binary(bin) do
    index = (:rand.uniform(@width * @height) - 1) * 3
    <<first::binary-size(index), _::binary-size(3), rest::binary>> = bin
    first <> <<0, 0, 0>> <> rest
  end

  defp load_texture(buffer) do
    # Generate texture id
    [tex_id | _] = :gl.genTextures(1)

    # Send texture to gp
    :gl.pixelStorei(:gl_const.gl_unpack_alignment, 1)
    :gl.bindTexture(:gl_const.gl_texture_2d, tex_id)
    # Configure texture
    :gl.texParameteri(:gl_const.gl_texture_2d, :gl_const.gl_texutre_mag_filter, :gl_const.gl_nearest)
    :gl.texParameteri(:gl_const.gl_texture_2d, :gl_const.gl_texutre_min_filter, :gl_const.gl_nearest)
    :gl.texImage2D(:gl_const.gl_texture_2d,
      0,
      :gl_const.gl_rgb,
      @width,
      @height,
      0,
      :gl_const.gl_rgb,
      :gl_const.gl_unsigned_byte,
      buffer)

    w = power_of_two_roof(@width)
    h = power_of_two_roof(@height)

    %{tex_id: tex_id, w: @width, h: @height, minx: 0.0, miny: 0.0, maxx: @width / w, maxy: @height / h}
  end
  
  defp setup_gl(win) do
    {w, h} = :wxWindow.getClientSize(win)
    resize_gl_scene(w, h)
    #:gl.shadeModel(:gl_const.gl_smooth)
    :gl.clearColor(0.0, 0.0, 0.0, 0.0)
    # :gl.clearDepth(1.0)
    # :gl.depthFunc(:gl_const.gl_lequal)
    # :gl.enable(:gl_const.gl_depth_test)
    # :gl.depthFunc(:gl_const.gl_lequal)
    # :gl.hint(:gl_const.gl_perspective_correction_hint, :gl_const.gl_nicest)
    setup_gl_2d(win)
    :ok
  end

  defp setup_gl_2d(win) do
    {w, h} = :wxWindow.getClientSize(win)

    # Note, there may be other things you need to change,
    # depending on how you have your OpenGL state set up.
    :gl.pushAttrib(:gl_const.gl_enable_bit)
    :gl.disable(:gl_const.gl_depth_test)
    :gl.disable(:gl_const.gl_cull_face)
    :gl.enable(:gl_const.gl_texture_2d)

    # This allows alpha blending of 2D textures with the scene
    # gl:enable(?GL_BLEND),
    # gl:blendFunc(?GL_SRC_ALPHA, ?GL_ONE_MINUS_SRC_ALPHA),

    :gl.matrixMode(:gl_const.gl_projection)
    :gl.pushMatrix()
    :gl.loadIdentity()

    # SDL coordinates will be upside-down in the OpenGL world.  We'll
    # therefore flip the bottom and top coordinates in the orthogonal
    # projection to correct this.  
    # Note: We could flip the texture/image itself, but this will
    # also work for mouse coordinates.
    :gl.ortho(0.0, w / 1, h / 1, 0.0, 0.0, 1.0)

    :gl.matrixMode(:gl_const.gl_modelview)
    :gl.pushMatrix()
    # :gl.loadIdentity()
    :ok
  end

  defp resize_gl_scene(width, height) do
    :gl.viewport(0, 0, width, height)
    :gl.matrixMode(:gl_const.gl_projection)
    :gl.loadIdentity()
    :gl.ortho(0.0, width / 1, height / 1, 0.0, 0.0, 1.0)
    # :glu.perspective(45.0, width / height, 0.1, 100.0)
    :gl.matrixMode(:gl_const.gl_modelview)
    :gl.loadIdentity()
    :ok
  end

  defp draw_texture(x, y, %{tex_id: tex_id, w: w, h: h, minx: minx, miny: miny, maxx: maxx, maxy: maxy}) do
    # :gl.clear(Bitwise.bor(:gl_const.gl_color_buffer_bit, :gl_const.gl_depth_buffer_bit))
    :gl.loadIdentity()
    :gl.bindTexture(:gl_const.gl_texture_2d, tex_id)
    :gl.scalef(@scale / 0.5, @scale / 0.5, 0.0)
    :gl.'begin'(:gl_const.gl_triangle_strip)
    :gl.texCoord2f(minx, miny)
    :gl.vertex2i(x, y)
    # :gl.texCoord2f(maxx, miny)
    :gl.texCoord2f(1.0, miny)
    :gl.vertex2i(x + div(w, 2), y)
    # :gl.texCoord2f(minx, maxy)
    :gl.texCoord2f(minx, 1.0)
    :gl.vertex2i(x, y + div(h, 2))
    # :gl.texCoord2f(maxx, maxy)
    :gl.texCoord2f(1.0, 1.0)
    :gl.vertex2i(x + div(w, 2), y + div(h, 2))
    :gl.'end'()
    :ok
  end


  defp render(%{canvas: canvas} = state) do
    # Update texture with new screen buffer
    :gl.texSubImage2D(:gl_const.gl_texture_2d, 0,
      0, 0,
      @width, @height,
      :gl_const.gl_rgb,
      :gl_const.gl_unsigned_byte,
      state.buffer)
    # Add number to texture
    if !is_nil(state.fps) do
      number = Minarai.Text.number_binary(state.fps)
      :gl.texSubImage2D(:gl_const.gl_texture_2d, 0,
        15 - number.w, 0,
        number.w, number.h,
        :gl_const.gl_rgb,
        :gl_const.gl_unsigned_byte,
        number.buffer)
    end
    draw_texture(0, 0, state.texture)
    :wxGLCanvas.swapBuffers(canvas)
    :ok
  end

  defp power_of_two_roof(x, n \\ 1)
  defp power_of_two_roof(x, n) when n >= x, do: n
  defp power_of_two_roof(x, n), do: power_of_two_roof(x, n * 2)
end
