#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
} ubuf;

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D maskSource;

void main()
{
    vec4 color = texture(source, qt_TexCoord0);
    vec3 mask = texture(maskSource, qt_TexCoord0).rgb;
    float alpha = max(max(mask.r, mask.g), mask.b);
    fragColor = vec4(color.rgb, color.a * alpha) * ubuf.qt_Opacity;
}
