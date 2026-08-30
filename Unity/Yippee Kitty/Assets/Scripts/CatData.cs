using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CatData : MonoBehaviour
{
    public int CatIndex = 0;
    public float CatMass = 1f;
    public int CatPoints = 0;

    private Rigidbody2D _rb;

    private void Awake()
    {
        _rb = GetComponent<Rigidbody2D>();

        _rb.mass = CatMass;
    }
}
