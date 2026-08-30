using System.Collections;
using System.Collections.Generic;
using Unity.VisualScripting;
using UnityEngine;

public class ColliderInformer : MonoBehaviour
{
    public bool WasCombinedIn { get; set; }

    public bool _hasCollided;

    private void OnCollisionEnter2D(Collision2D other)
    {
        DropperController.instance.canSpawnCat = true;

        if (!_hasCollided && !WasCombinedIn)
        {
            _hasCollided = true;
            Destroy(this);
        }
    }
}
