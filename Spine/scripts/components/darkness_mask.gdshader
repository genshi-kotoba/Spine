shader_type canvas_item;

// DarknessMask — 挖孔 canvas_item shader（C3 前置需求③，方案 B 定案）
// 一个覆盖视口的 ColorRect 挂本 ShaderMaterial：孔内透明（透出场景），孔外为遮罩色。
// 中心以视口归一化 UV 传入（脚本每帧换算全局坐标→UV），支持软边圆孔。
// 明暗：mask = 1 - smoothstep(inner_radius, outer_radius, dist)

uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float inner_radius = 0.12;
uniform float outer_radius = 0.30;
uniform vec4 darkness_color : source_color = vec4(0.0, 0.0, 0.0, 0.85);
uniform float softness = 0.5;
uniform bool enabled = true;

void fragment() {
	vec4 out_color = vec4(0.0, 0.0, 0.0, 0.0);
	if (enabled) {
		float dist = distance(UV, center_uv);
		// softness 控制边缘过渡：inner/outer 之间的软边（数值越大过渡越居中）
		float inner = inner_radius;
		float outer = max(outer_radius, inner + 0.0001);
		// mask：孔内=0（透明），孔外=1（遮罩）
		float mask = 1.0 - smoothstep(inner, outer, dist);
		out_color = vec4(darkness_color.rgb, darkness_color.a * mask);
	}
	COLOR = out_color;
}
