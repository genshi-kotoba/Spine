shader_type canvas_item;
// glitch_char.gdshader — 故障单字效果
// 水平切片错位 + RGB 通道分离 + 随机闪烁；强度/频率均可调

uniform float slice_strength : hint_range(0.0, 20.0) = 4.0;   // 切片错位幅度(px)
uniform float slice_speed : hint_range(0.0, 60.0) = 8.0;      // 切片跳变频率
uniform float aberration : hint_range(0.0, 10.0) = 1.5;       // RGB 分离(px)
uniform float flicker_speed : hint_range(0.0, 60.0) = 20.0;   // 闪烁频率
uniform float flicker_strength : hint_range(0.0, 1.0) = 0.3;  // 闪烁幅度
uniform float rows : hint_range(4.0, 64.0) = 24.0;            // 切片条数

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

void fragment() {
	vec2 uv = UV;

	// 1) 水平切片错位：按行分条，每条随机 x 偏移
	float row = floor(uv.y * rows);
	float tick = floor(TIME * slice_speed);
	float r = hash11(row * 17.0 + tick * 91.0);
	float offset = (r - 0.5) * 2.0 * slice_strength * TEXTURE_PIXEL_SIZE.x;
	// 只有部分条参与错位，避免整体漂移
	offset *= step(0.6, hash11(row * 31.0 + tick * 7.0));
	uv.x += offset;

	// 2) RGB 通道分离
	vec2 px = vec2(aberration * TEXTURE_PIXEL_SIZE.x, 0.0);
	float cr = texture(TEXTURE, uv + px).r;
	float cg = texture(TEXTURE, uv).g;
	float cb = texture(TEXTURE, uv - px).b;
	float ca = texture(TEXTURE, uv).a;
	vec4 col = vec4(cr, cg, cb, ca);

	// 3) 闪烁：连续 alpha 抖动 + 小概率瞬时隐现
	float seed = hash11(row + 3.7);
	float wave = 0.5 + 0.5 * sin(TIME * flicker_speed + seed * 6.2831);
	col.a *= 1.0 - flicker_strength * wave;
	float drop = hash11(tick * 13.0 + seed * 57.0);
	if (drop > 0.98) {
		col.a *= 0.2;
	}

	COLOR = col;
}
