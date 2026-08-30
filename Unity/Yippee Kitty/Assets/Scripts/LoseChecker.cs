using UnityEngine;

public class LoseChecker : MonoBehaviour
{
    public float loseTime;
    private float timer = 0f;
    private bool isInside = false;

    // Method to manually activate the trigger
    public void ActivateTrigger()
    {
        isInside = true;
    }

    private void Update()
    {
        if (isInside)
        {
            timer += Time.deltaTime;
            if (timer > loseTime)
            {
                GameManager.instance.gameOver();
            }
        }
    }

    private void OnTriggerEnter2D(Collider2D other)
    {
        if (other.CompareTag("Lose"))
        {
            isInside = true;
        }
    }

    private void OnTriggerExit2D(Collider2D other)
    {
        if (other.CompareTag("Lose"))
        {
            isInside = false;
            timer = 0f; // Reset timer when object exits the trigger
        }
    }
}
