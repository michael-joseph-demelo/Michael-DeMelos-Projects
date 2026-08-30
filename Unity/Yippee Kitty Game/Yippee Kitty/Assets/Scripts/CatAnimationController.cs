using UnityEngine;

public class CatAnimationController : MonoBehaviour
{
    private Rigidbody2D rb;
    private Animator animator;
    private bool isGrounded;

    void Start()
    {
        rb = GetComponent<Rigidbody2D>();
        animator = GetComponent<Animator>();
    }

    void Update()
    {
        CheckFalling();
        CheckHanging();
        CheckIdle();
        //Debug.Log("Simulated: " + rb.simulated);
    }

    void CheckFalling()
    {
        bool isFalling = rb.simulated && !isGrounded;
        animator.SetBool("isFalling", isFalling);
        //Debug.Log("isFalling: " + isFalling);
    }

    void CheckHanging()
    {
        bool isHanging = !rb.simulated;
        animator.SetBool("isHanging", isHanging);
        //Debug.Log("isHanging: " + isHanging);
    }

    void CheckIdle()
    {
        bool isIdle = rb.simulated && isGrounded;
        animator.SetBool("isIdle", isIdle);
        //Debug.Log("isIdle: " + isIdle);
    }

    void OnCollisionEnter2D(Collision2D collision)
    {
        isGrounded = true;
    }

    void OnCollisionExit2D(Collision2D collision)
    {
        isGrounded = false;
    }
}
