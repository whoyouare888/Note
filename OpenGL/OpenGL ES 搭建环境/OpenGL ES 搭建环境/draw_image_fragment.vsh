#version 300 es
precision highp float;

out vec4 FragColor;
in vec2 TexCoord;
uniform sampler2D Texture;

void main()
{
    FragColor = texture(Texture, TexCoord);
}
