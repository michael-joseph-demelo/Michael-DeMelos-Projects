using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class QuitGame : MonoBehaviour
{
    void Start()
    {
        Button quitButton = GetComponent<Button>(); // Assuming the button is attached to the same GameObject
        quitButton.onClick.AddListener(Quit);
    }

    public void Quit()
    {
        Time.timeScale = 1f; // Set Time.timeScale back to normal
        int mainMenuSceneIndex = 0; // Replace with the build index of your game scene
        SceneManager.LoadScene(mainMenuSceneIndex);
    }
}