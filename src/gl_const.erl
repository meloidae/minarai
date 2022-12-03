-module(gl_const).
-compile(export_all).

-include_lib("wx/include/gl.hrl").

smooth() ->
  ?GL_SMOOTH.

enable_bit() ->
  ?GL_ENABLE_BIT.

cull_face() ->
  ?GL_CULL_FACE.

blend() ->
  ?GL_BLEND.

depth_test() ->
  ?GL_DEPTH_TEST.

lequal() ->
  ?GL_LEQUAL.

perspective_correction_hint() ->
  ?GL_PERSPECTIVE_CORRECTION_HINT.

nicest() ->
  ?GL_NICEST.

color_buffer_bit() ->
  ?GL_COLOR_BUFFER_BIT.

depth_buffer_bit() ->
  ?GL_DEPTH_BUFFER_BIT.

triangles() ->
  ?GL_TRIANGLES.

triangle_strip() ->
  ?GL_TRIANGLE_STRIP.

polygon() ->
  ?GL_POLYGON.

projection() ->
  ?GL_PROJECTION.

modelview() ->
  ?GL_MODELVIEW.

texture_2d() ->
  ?GL_TEXTURE_2D.

rgb() ->
  ?GL_RGB.

rgba() ->
  ?GL_RGBA.

unpack_alignment() ->
  ?GL_UNPACK_ALIGNMENT.

unsigned_byte() ->
  ?GL_UNSIGNED_BYTE.

texutre_mag_filter() ->
  ?GL_TEXTURE_MAG_FILTER.

texutre_min_filter() ->
  ?GL_TEXTURE_MIN_FILTER.

texutre_wrap_s() ->
  ?GL_TEXTURE_WRAP_S.

texutre_wrap_t() ->
  ?GL_TEXTURE_WRAP_T.

nearest() ->
  ?GL_NEAREST.

repeat() ->
  ?GL_REPEAT.

read_framebuffer() ->
  ?GL_READ_FRAMEBUFFER.

color_attachment0() ->
  ?GL_COLOR_ATTACHMENT0.
