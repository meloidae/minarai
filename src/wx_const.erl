-module(wx_const).
-compile(export_all).

-include_lib("wx/include/wx.hrl").

id_any() ->
  ?wxID_ANY.

sunken_border() ->
  ?wxSUNKEN_BORDER.

gl_rgba() ->
  ?WX_GL_RGBA.

gl_doublebuffer() ->
 ?WX_GL_DOUBLEBUFFER.

gl_min_red() ->
  ?WX_GL_MIN_RED.

gl_min_green() ->
  ?WX_GL_MIN_GREEN.

gl_min_blue() ->
  ?WX_GL_MIN_BLUE.
  
gl_depth_size() ->
  ?WX_GL_DEPTH_SIZE.
