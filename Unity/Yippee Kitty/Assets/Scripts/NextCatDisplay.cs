using UnityEngine;
using UnityEngine.UI;

public class NextCatDisplay : MonoBehaviour
{
    public Sprite[] spriteList; // List of sprites to choose from
    private SpriteRenderer spriteRenderer;

    // Start is called before the first frame update
    void Start()
    {
        spriteRenderer = GetComponent<SpriteRenderer>();
    }

    // Update is called once per frame
    void Update()
    {
        ChangeSprite();
    }

    // Method to change the currently displayed sprite
    public void ChangeSprite()
    {
        spriteRenderer.sprite = spriteList[DropperController.instance.nextCat];
    }
}
