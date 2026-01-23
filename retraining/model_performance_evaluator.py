"""
Model Performance Evaluator
===========================

A standalone utility for calculating segmentation metrics (F1, IoU, Precision, Recall)
for a trained model against a ground-truth validation set.

Dependencies:
    torch
    model_utils (Rootpainter module)
    metrics (Rootpainter module)
"""

import os
import sys
import argparse
import tkinter as tk
from tkinter import filedialog
from typing import Dict, Any, Optional

# --- Local Module Imports ---
# Ensure model_utils.py and metrics.py are in the python path
try:
    import model_utils
except ImportError:
    print("Error: Could not import 'model_utils'. Ensure the file exists in the script directory.")
    sys.exit(1)

# Inference Parameters
# RootPainter defaults: Input 572px, Output 500px (due to unpadded convolutions)
INPUT_WIDTH = 572
OUTPUT_WIDTH = 500
BATCH_SIZE = 1


def calculate_model_scores(model_path: str, mask_dir: str, img_dir: str) -> None:
    """
    Loads a trained model and computes performance metrics on the validation set.
    """
    # 1. Path Verification
    if not _validate_paths(model_path, mask_dir, img_dir):
        return

    # 2. Setup Device
    device = model_utils.get_device()
    print(f"Device: {device}")

    # 3. Load Model
    print(f"Loading model: {os.path.basename(model_path)}...")
    try:
        model = model_utils.load_model(model_path)
        model.eval()
    except Exception as e:
        print(f"Fatal Error: Failed to load model. {e}")
        return

    print("Starting evaluation. This may take some time...")

    # 4. Calculate Metrics
    try:
        metrics = model_utils.get_val_metrics(
            cnn=model,
            val_annot_dir=mask_dir,
            dataset_dir=img_dir,
            in_w=INPUT_WIDTH,
            out_w=OUTPUT_WIDTH,
            bs=BATCH_SIZE
        )
    except Exception as e:
        print(f"Fatal Error: Failed during metric calculation. {e}")
        return

    # 5. Report Results
    _print_results(metrics)


def _validate_paths(model_path: str, mask_dir: str, img_dir: str) -> bool:
    """Checks if all required file paths exist."""
    valid = True
    if not os.path.exists(model_path):
        print(f"[Error] Model file not found: {model_path}")
        valid = False
    if not os.path.exists(mask_dir):
        print(f"[Error] Validation mask directory not found: {mask_dir}")
        valid = False
    if not os.path.exists(img_dir):
        print(f"[Error] Raw image directory not found: {img_dir}")
        valid = False
    return valid


def _print_results(metrics: Dict[str, Any]) -> None:
    """Formats and prints the evaluation metrics to the console."""
    print("\n" + "=" * 30)
    print("PERFORMANCE REPORT")
    print("=" * 30)
    
    # Primary Metrics
    print(f"F1 Score (Dice):     {metrics.get('f1', 0.0):.4f}")
    print(f"IoU (Jaccard):       {metrics.get('iou', 0.0):.4f}")
    print(f"Precision:           {metrics.get('precision', 0.0):.4f}")
    print(f"Recall:              {metrics.get('recall', 0.0):.4f}")
    
    print("-" * 30)
    
    # Raw Counts
    print(f"True Positives:      {metrics.get('TP', 0)}")
    print(f"False Positives:     {metrics.get('FP', 0)}")
    print(f"False Negatives:     {metrics.get('FN', 0)}")
    print("=" * 30)


def get_paths_via_args_or_dialog():
    """
    Parses CLI arguments. If missing, launches Tkinter dialogs to ask the user.
    """
    parser = argparse.ArgumentParser(
        description="Calculate segmentation metrics for a RootPainter model."
    )
    parser.add_argument("--model", help="Path to the trained model file (.pkl).")
    parser.add_argument("--masks", help="Directory containing ground-truth masks.")
    parser.add_argument("--images", help="Directory containing raw validation images.")

    args = parser.parse_args()

    # If all args are provided via CLI, return them
    if args.model and args.masks and args.images:
        return args.model, args.masks, args.images

    # Otherwise, fallback to GUI dialogs
    print("Arguments not fully provided. Launching selector...")
    root = tk.Tk()
    root.withdraw()

    model_path = args.model or filedialog.askopenfilename(
        title="Select Model File (.pkl)",
        filetypes=[("Pickle Files", "*.pkl"), ("All Files", "*.*")]
    )
    if not model_path: return None, None, None

    mask_dir = args.masks or filedialog.askdirectory(title="Select Ground Truth Masks Folder")
    if not mask_dir: return None, None, None

    img_dir = args.images or filedialog.askdirectory(title="Select Raw Images Folder")
    if not img_dir: return None, None, None

    return model_path, mask_dir, img_dir


if __name__ == "__main__":
    path_model, dir_masks, dir_images = get_paths_via_args_or_dialog()
    
    if not path_model:
        print("Selection cancelled.")
    else:
        calculate_model_scores(path_model, dir_masks, dir_images)