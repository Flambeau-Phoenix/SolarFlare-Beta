How to use atlas.py:

Put this python script in an isolated folder along with the images you'd like to combine into a sole atlas. 
Using CMD/Powershell or whichever terminal you use type "python atlas.py" while cd in the folder with the script.
It will produce a single atlas image, and a .json, mapping out the atlas so you can reference it in your works.

Example:


```json
    "Axe_Base_Attack.png": {
      "x": 3072,
      "y": 512,
      "w": 96,
      "h": 96,
      "atlas_w": 4096,
      "atlas_h": 2048
    },
```

