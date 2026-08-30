using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class StartButton : MonoBehaviour
{
    void Start()
    {
        // Get the Button component attached to this GameObject
        Button button = GetComponent<Button>();

        // Add a listener for when the button is clicked and call the StartGame method
        button.onClick.AddListener(StartGame);
    }

    // Function to be called when the start button is clicked
    public void StartGame()
    {
        int gameSceneIndex = 1; // Replace with the build index of your game scene
        SceneManager.LoadScene(gameSceneIndex);
    }
}
