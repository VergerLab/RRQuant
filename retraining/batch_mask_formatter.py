import os
import argparse
import sys
import tkinter as tk
from tkinter import filedialog
from PIL import Image
import numpy as np
from glob import glob

def recolor_mask(source_path, dest_path, fg_color, bg_color, threshold=50):
    """
    Replaces the background and foreground of a segmentation mask with solid colors.
    """
    try:
        # Open the source mask and ensure it's in RGB format.
        mask_img = Image.open(source_path).convert("RGB")
        mask_arr = np.array(mask_img)

        # Identify background pixels (dark pixels)
        is_background = np.sum(mask_arr, axis=2) < threshold
        
        # Identify foreground pixels (everything else)
        is_foreground = ~is_background

        # Create a new array, starting with the background color
        new_annot_arr = np.full(mask_arr.shape, bg_color, dtype=np.uint8)

        # Where the foreground is identified, set the pixel color
        new_annot_arr[is_foreground] = fg_color

        # Save the new annotation file.
        Image.fromarray(new_annot_arr).save(dest_path)
        
    except Exception as e:
        print(f"Failed to process {source_path}: {e}")

def get_paths_via_args_or_dialog():
    """
    Parses CLI arguments. If missing, launches Tkinter dialogs to ask the user.
    """
    parser = argparse.ArgumentParser(
        description="Batch convert segmentation masks to RootPainter format."
    )
    parser.add_argument(
        "--input", 
        help="Directory containing the original segmentation masks (PNG)."
    )
    parser.add_argument(
        "--output", 
        help="Directory to save the formatted masks."
    )

    args = parser.parse_args()

    # If all args are provided via CLI, return them
    if args.input and args.output:
        return args.input, args.output

    # Otherwise, fallback to GUI dialogs
    print("Arguments not fully provided. Launching directory selector...")
    root = tk.Tk()
    root.withdraw()

    input_dir = args.input or filedialog.askdirectory(title="Select Input Folder (Source Masks)")
    if not input_dir: return None, None

    output_dir = args.output or filedialog.askdirectory(title="Select Output Folder (Formatted Masks)")
    if not output_dir: return None, None

    return input_dir, output_dir

if __name__ == "__main__":
    # --- Configuration ---
    # RootPainter Standard: Background=Green, Foreground=Red
    BACKGROUND_COLOR = [0, 255, 0] 
    FOREGROUND_COLOR = [255, 0, 0] 
    BACKGROUND_THRESHOLD = 50       

    # --- Get Paths ---
    input_dir, output_dir = get_paths_via_args_or_dialog()

    if not input_dir:
        print("Selection cancelled.")
        sys.exit(0)

    # --- Validation ---
    if not os.path.exists(output_dir):
        print(f"Creating output directory: {output_dir}")
        os.makedirs(output_dir)

    # --- Execution ---
    mask_files = glob(os.path.join(input_dir, "*.png"))

    if not mask_files:
        print(f"No PNG files found in {input_dir}")
    else:
        print(f"Found {len(mask_files)} masks in '{input_dir}'. Processing...")
        
        for f in mask_files:
            basename = os.path.basename(f)
            dest_path = os.path.join(output_dir, basename)
            
            recolor_mask(f, 
                         dest_path, 
                         FOREGROUND_COLOR, 
                         BACKGROUND_COLOR, 
                         BACKGROUND_THRESHOLD)
                         
        print(f"Processing complete. Output saved to: {output_dir}")
