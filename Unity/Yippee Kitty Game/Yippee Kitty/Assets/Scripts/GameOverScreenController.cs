using UnityEngine;
using UnityEngine.UI;
using UnityEngine.SceneManagement;

public class GameOverScreenController : MonoBehaviour
{
    public Button retryButton;
    public Button yesButton;
    public Button noButton;

    private void Start()
    {
        retryButton.onClick.AddListener(ShowConfirmationButtons);
        yesButton.onClick.AddListener(ResetScene);
        noButton.onClick.AddListener(HideConfirmationButtons);

        // Initially hide the Yes and No buttons
        yesButton.gameObject.SetActive(false);
        noButton.gameObject.SetActive(false);
    }

    private void OnDestroy()
    {
        retryButton.onClick.RemoveListener(ShowConfirmationButtons);
        yesButton.onClick.RemoveListener(ResetScene);
        noButton.onClick.RemoveListener(HideConfirmationButtons);
    }

    private void ShowConfirmationButtons()
    {
        // Show the Yes and No buttons
        yesButton.gameObject.SetActive(true);
        noButton.gameObject.SetActive(true);
    }

    private void HideConfirmationButtons()
    {
        // Hide the Yes and No buttons
        yesButton.gameObject.SetActive(false);
        noButton.gameObject.SetActive(false);
    }

    private void ResetScene()
    {
        // Reset the scene
        SceneManager.LoadScene(SceneManager.GetActiveScene().name);
    }
}
