shader_type canvas_item;
render_mode unshaded;

// 走廊墙/地面滚动 shader（corridor_rework_spec §5.1 / D-R3，修 B2）。白模用。
// UV 单位 = 平铺格（1 格 = tile_world_px 世界像素；与 WallVisual/GroundVisual 的 uv 网格一致）。
// 驱动方式（二选一，勿同时启用）：
//   a) texture_offset（世界像素，推荐）：外部每帧累加写入 → 纹理按世界速度精确滚动，MCP 可读回；
//      CorridorVisualLayer 与 Corridor._scroll_texture 兼容分支均按此约定驱动。
//   b) TIME 自主滚动（规格原式，调试用）：scroll_speed != 0 时生效。
// v1.1 B2 实测修正（与规格原式的差异，必要）：corridor_wall.png 为纯水平条纹纹理
// （row_var=0.0，T(u,v) 仅随 v 变化），只平移 u 则画面比特级不变、0.5s 双帧截图位移=0。
// 因此 texture_offset.x 同时写入 uv.y（配合 CorridorVisualLayer.x_phase_uv 把纹理行
// 沿世界 x 轴展开：T=f(x/64-Δ)），图案以精确世界速度左移（实测截图差分 >30%）。
uniform sampler2D tex : source_color, repeat_enable;
uniform float scroll_speed = 0.0;
uniform float tex_scale : hint_range(0.01, 100.0) = 1.0;
uniform vec2 texture_offset = vec2(0.0);
uniform float tile_world_px : hint_range(1.0, 4096.0) = 64.0;

void fragment() {
	vec2 uv = UV * vec2(tex_scale, 1.0);
	uv.x -= TIME * scroll_speed / tex_scale;
	uv.x -= texture_offset.x / tile_world_px;
	uv.y -= (TIME * scroll_speed + texture_offset.x) / tile_world_px;
	uv.y -= texture_offset.y / tile_world_px;
	COLOR = texture(tex, uv);
}
