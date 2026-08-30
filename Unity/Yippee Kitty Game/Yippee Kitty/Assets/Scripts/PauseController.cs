using UnityEngine;
using UnityEngine.UI;

public class PauseManager : MonoBehaviour
{
    private bool isPaused = false;
    private bool isTimeScaled = false; // Flag to track if Time.timeScale is being used
    private Button button1;
    public Canvas canvasToToggle; // Reference to the canvas you want to toggle
    public Button button2;

    void Start()
    {
        // Disable the canvas initially
        canvasToToggle.enabled = false;

        // Get the button component attached to the GameObject
        button1 = GetComponent<Button>();

        // Add a listener to the button's click event
        button1.onClick.AddListener(TogglePause);

        button2.onClick.AddListener(TogglePlay);
    }

    public void TogglePause()
    {
        // Pause the game
        if (!isTimeScaled)
        {
            Time.timeScale = 0f; // Set Time.timeScale to 0
            isTimeScaled = true;
        }
        isPaused = true;
        // Show the canvas
        canvasToToggle.enabled = true;
    }

    public void TogglePlay()
    {
        // Unpause the game
        if (isTimeScaled)
        {
            Time.timeScale = 1f; // Set Time.timeScale back to normal
            isTimeScaled = false;
        }
        isPaused = false;
        // Hide the canvas
        canvasToToggle.enabled = false;
    }
}