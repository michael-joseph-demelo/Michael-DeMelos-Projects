using UnityEngine;

public class UI_ColourChanger : MonoBehaviour
{
    public SpriteRenderer[] spriteRenderers;
    public Color[] colors;

    void Start()
    {
        // Ensure sprite renderers and colors arrays are of the same length
        if (spriteRenderers.Length != colors.Length)
        {
            Debug.LogError("Sprite renderers and colors arrays must have the same length.");
            return;
        }

        // Change the color of each sprite renderer to the corresponding color
        for (int i = 0; i < spriteRenderers.Length; i++)
        {
            spriteRenderers[i].color = colors[i];
        }
    }
}
