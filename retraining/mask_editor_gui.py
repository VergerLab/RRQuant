"""
Image Mask Editor
=================

A Pygame-based tool for annotated image segmentation masks.
Features include pan, zoom, brush resizing, undo/redo history, and
handling of high-resolution images via dynamic downscaling.

Dependencies:
    pygame, contextlib, PIL (Pillow), numpy, tkinter
"""

import os
import sys
import argparse
from typing import List, Tuple, Optional, Dict, Any

import pygame
import numpy as np
import tkinter as tk
from tkinter import filedialog
from PIL import Image

# --- Configuration & Constants ---
SCREEN_DIMS = (1280, 720)

# Brush Settings
BRUSH_STEP = 2
BRUSH_MIN = 1
BRUSH_MAX = 200

# Zoom Settings
ZOOM_FACTOR = 1.1
ZOOM_MAX = 20.0  # 2000%

# Performance & History
HISTORY_LIMIT = 30
MAX_WORKING_PIXELS = 10_000_000  # Downscale images larger than ~3162x3162

# Colors (R, G, B, A)
COLOR_CYAN = (0, 255, 255)
COLOR_TRANSPARENT = (0, 0, 0, 0)
COLOR_CURSOR = (255, 255, 255)
COLOR_BACKGROUND = (50, 50, 50)

# Overlay Opacity
MASK_ALPHA_DISPLAY = 64
MASK_ALPHA_SAVE = 255


class MaskEditor:
    """
    Interactive GUI for editing segmentation masks.
    """
    def __init__(self, tif_folder: str, mask_folder: str, output_folder: str):
        self.tif_folder = tif_folder
        self.mask_folder = mask_folder
        self.output_folder = output_folder

        if not os.path.exists(self.output_folder):
            os.makedirs(self.output_folder)

        self.file_list = self._create_file_list()
        if not self.file_list:
            raise FileNotFoundError("No matching TIF/PNG pairs found in the selected folders.")

        # Pygame Initialization
        pygame.init()
        self.screen = pygame.display.set_mode(SCREEN_DIMS, pygame.RESIZABLE)
        pygame.display.set_caption("Mask Editor")
        self.clock = pygame.time.Clock()

        # Editor State
        self.current_index = 0
        self.brush_size = 15
        self.running = True
        self.drawing = False
        self.erasing = False
        self.panning = False
        self.last_draw_pos: Optional[Tuple[int, int]] = None

        # Viewport State
        self.camera_offset = pygame.Vector2(0, 0)
        self.zoom_level = 1.0
        self.min_zoom = 1.0

        # Image Data
        self.original_image: Optional[Image.Image] = None  # Kept if downscaled
        self.rescale_factor = 1.0
        self.background_img: Optional[pygame.Surface] = None
        self.editable_mask: Optional[pygame.Surface] = None

        # History
        self.undo_stack: List[pygame.Surface] = []
        self.redo_stack: List[pygame.Surface] = []

        self.load_current_image()

    def _create_file_list(self) -> List[Dict[str, str]]:
        """Scans directories to match TIF images with PNG masks."""
        file_list = []
        # Support both .tif and .tiff
        tif_files = sorted([f for f in os.listdir(self.tif_folder) if f.lower().endswith(('.tif', '.tiff'))])
        
        for tif_file in tif_files:
            basename = os.path.splitext(tif_file)[0]
            mask_file = basename + '.png'
            mask_path = os.path.join(self.mask_folder, mask_file)
            
            # Only add files where both image and mask exist
            if os.path.exists(mask_path):
                file_list.append({
                    "tif": os.path.join(self.tif_folder, tif_file),
                    "mask": mask_path,
                    "output": os.path.join(self.output_folder, mask_file)
                })
        return file_list

    @staticmethod
    def pil_to_pygame(pil_image: Image.Image, mode: str = 'RGB') -> pygame.Surface:
        """Converts a PIL image to a Pygame Surface."""
        if mode == 'RGBA':
            pil_image = pil_image.convert('RGBA')
        else:
            pil_image = pil_image.convert('RGB')
            
        return pygame.image.fromstring(
            pil_image.tobytes(), pil_image.size, pil_image.mode
        ).convert_alpha()

    def load_current_image(self) -> None:
        """Loads the image and mask at `current_index`. Prioritizes saved output masks."""
        if not (0 <= self.current_index < len(self.file_list)):
            self.current_index = max(0, min(self.current_index, len(self.file_list) - 1))
            return

        paths = self.file_list[self.current_index]
        print(f"Loading [{self.current_index + 1}/{len(self.file_list)}]: {os.path.basename(paths['tif'])}")

        # Reset scaling state
        self.original_image = None
        self.rescale_factor = 1.0

        # --- Load Source Image ---
        try:
            tif_pil = Image.open(paths['tif'])
            w, h = tif_pil.size
            
            if w * h > MAX_WORKING_PIXELS:
                self.original_image = tif_pil
                self.rescale_factor = (MAX_WORKING_PIXELS / (w * h)) ** 0.5
                new_size = (int(w * self.rescale_factor), int(h * self.rescale_factor))
                print(f"  -> High-res ({w}x{h}). Downscaling to {new_size}.")
                tif_pil = tif_pil.resize(new_size, Image.Resampling.LANCZOS)

            self.background_img = self.pil_to_pygame(tif_pil)
        except Exception as e:
            print(f"Error loading TIF: {e}")
            self.background_img = pygame.Surface((1000, 1000))
            self.background_img.fill((255, 0, 0))

        # --- Load Mask (MODIFIED) ---
        try:
            # Check if an edited version already exists in the output folder
            if os.path.exists(paths['output']):
                load_path = paths['output']
                print(f"  -> Loading saved mask from: {os.path.basename(load_path)}")
            else:
                load_path = paths['mask']
                print(f"  -> Loading original mask from: {os.path.basename(load_path)}")

            mask_pil = Image.open(load_path).convert("RGBA")
            
            if self.rescale_factor != 1.0:
                mask_pil = mask_pil.resize(self.background_img.get_size(), Image.Resampling.NEAREST)

            # Create visualization overlay (Cyan)
            mask_np = np.array(mask_pil)
            cyan_mask_np = np.zeros_like(mask_np)
            
            # Assuming channel 3 is alpha/mask data. Adjust if your saved masks use different channels.
            if mask_np.shape[2] == 4:
                mask_active = mask_np[:, :, 3] > 0
            else:
                mask_active = mask_np > 0 # Handle grayscale if necessary

            cyan_mask_np[mask_active] = [*COLOR_CYAN, MASK_ALPHA_DISPLAY]
            
            self.editable_mask = self.pil_to_pygame(Image.fromarray(cyan_mask_np), 'RGBA')
        except Exception as e:
            print(f"Error loading mask: {e}. Initializing blank mask.")
            self.editable_mask = pygame.Surface(self.background_img.get_size(), pygame.SRCALPHA)

        # --- Reset Viewport ---
        self.camera_offset.update(0, 0)
        img_w, img_h = self.background_img.get_size()
        screen_w, screen_h = self.screen.get_size()

        self.zoom_level = min(screen_w / img_w, screen_h / img_h)
        self.min_zoom = self.zoom_level
        self.camera_offset = self._get_centered_offset()

        self.undo_stack.clear()
        self.redo_stack.clear()
        self.update_caption()

    def _push_undo_state(self) -> None:
        self.redo_stack.clear()
        self.undo_stack.append(self.editable_mask.copy())
        if len(self.undo_stack) > HISTORY_LIMIT:
            self.undo_stack.pop(0)

    def _undo(self) -> None:
        if not self.undo_stack: return
        self.redo_stack.append(self.editable_mask.copy())
        self.editable_mask = self.undo_stack.pop()

    def _redo(self) -> None:
        if not self.redo_stack: return
        self.undo_stack.append(self.editable_mask.copy())
        self.editable_mask = self.redo_stack.pop()

    def _get_centered_offset(self) -> pygame.Vector2:
        img_w, img_h = self.background_img.get_size()
        screen_w, screen_h = self.screen.get_size()
        
        offset_x = (img_w / 2) - (screen_w / 2) / self.zoom_level
        offset_y = (img_h / 2) - (screen_h / 2) / self.zoom_level
        return pygame.Vector2(offset_x, offset_y)

    def save_current_mask(self) -> None:
        if not (0 <= self.current_index < len(self.file_list)):
            return

        output_path = self.file_list[self.current_index]['output']
        print(f"Saving to {os.path.basename(output_path)}...")

        img_str = pygame.image.tostring(self.editable_mask, 'RGBA', False)
        working_mask_pil = Image.frombytes('RGBA', self.editable_mask.get_size(), img_str)

        if self.original_image is not None:
            print(f"  -> Upscaling to original size: {self.original_image.size}")
            final_mask_pil = working_mask_pil.resize(self.original_image.size, Image.Resampling.NEAREST)
        else:
            final_mask_pil = working_mask_pil

        mask_data = np.array(final_mask_pil)
        final_array = np.zeros_like(mask_data)
        
        mask_indices = mask_data[:, :, 3] > 0
        final_array[mask_indices] = (*COLOR_CYAN, MASK_ALPHA_SAVE)

        Image.fromarray(final_array, 'RGBA').save(output_path, 'PNG')

    def update_caption(self) -> None:
        filename = os.path.basename(self.file_list[self.current_index]['tif'])
        zoom_pct = int(self.zoom_level / self.min_zoom * 100)
        caption = (f"Mask Editor | {filename} ({self.current_index + 1}/{len(self.file_list)}) "
                   f"| Brush: {self.brush_size} | Zoom: {zoom_pct}%")
        pygame.display.set_caption(caption)

    def run(self) -> None:
        while self.running:
            self.handle_events()
            self.draw_updates()
            self.clock.tick(60)
        pygame.quit()

    def handle_events(self) -> None:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.VIDEORESIZE:
                self.load_current_image()
            elif event.type == pygame.KEYDOWN:
                mods = pygame.key.get_mods()
                if (mods & pygame.KMOD_CTRL) and event.key == pygame.K_z:
                    self._undo()
                elif (mods & pygame.KMOD_CTRL) and event.key == pygame.K_y:
                    self._redo()
                elif event.key == pygame.K_s:
                    self.save_current_mask()
                    self.current_index += 1
                    self.load_current_image()
                elif event.key == pygame.K_RIGHT:
                    self.current_index = min(self.current_index + 1, len(self.file_list) - 1)
                    self.load_current_image()
                elif event.key == pygame.K_LEFT:
                    self.current_index = max(self.current_index - 1, 0)
                    self.load_current_image()
            elif event.type == pygame.MOUSEWHEEL:
                if pygame.key.get_mods() & pygame.KMOD_SHIFT:
                    self.brush_size += event.y * BRUSH_STEP
                    self.brush_size = max(BRUSH_MIN, min(self.brush_size, BRUSH_MAX))
                else:
                    self._handle_zoom(event.y)
                self.update_caption()
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button in [1, 3]:
                    self._push_undo_state()
                    self.last_draw_pos = event.pos
                    self.edit_mask(event.pos)
                if event.button == 1: self.drawing = True
                elif event.button == 2: self.panning = True
                elif event.button == 3: self.erasing = True
            elif event.type == pygame.MOUSEBUTTONUP:
                if event.button == 1: self.drawing = False
                elif event.button == 2: self.panning = False
                elif event.button == 3: self.erasing = False
                self.last_draw_pos = None
            elif event.type == pygame.MOUSEMOTION:
                if self.panning:
                    self.camera_offset -= pygame.Vector2(event.rel) / self.zoom_level
                elif self.drawing or self.erasing:
                    self.edit_mask(event.pos)

    def _handle_zoom(self, scroll_direction: int) -> None:
        if scroll_direction > 0:
            mouse_pos = pygame.Vector2(pygame.mouse.get_pos())
            world_pos_before = self.camera_offset + (mouse_pos / self.zoom_level)
            self.zoom_level = min(self.zoom_level * ZOOM_FACTOR, ZOOM_MAX)
            self.camera_offset = world_pos_before - (mouse_pos / self.zoom_level)
        else:
            old_zoom = self.zoom_level
            self.zoom_level = max(self.zoom_level / ZOOM_FACTOR, self.min_zoom)
            screen_center = pygame.Vector2(self.screen.get_rect().center)
            world_center = self.camera_offset + (screen_center / old_zoom)
            offset_screen_centric = world_center - (screen_center / self.zoom_level)
            target_offset = self._get_centered_offset()
            start_interp = 2.0 * self.min_zoom
            t = 0.0
            if start_interp - self.min_zoom > 0:
                progress = (start_interp - self.zoom_level) / (start_interp - self.min_zoom)
                t = max(0.0, min(1.0, progress))
            self.camera_offset = offset_screen_centric.lerp(target_offset, t)

    def edit_mask(self, screen_pos: Tuple[int, int]) -> None:
        current_world_pos = self.camera_offset + (pygame.Vector2(screen_pos) / self.zoom_level)
        brush_radius = self.brush_size / self.zoom_level
        color = (*COLOR_CYAN, MASK_ALPHA_DISPLAY) if self.drawing else COLOR_TRANSPARENT
        if self.last_draw_pos:
            last_world_pos = self.camera_offset + (pygame.Vector2(self.last_draw_pos) / self.zoom_level)
            pygame.draw.line(self.editable_mask, color, last_world_pos, current_world_pos, int(brush_radius * 2))
        pygame.draw.circle(self.editable_mask, color, current_world_pos, brush_radius)
        self.last_draw_pos = screen_pos

    def draw_updates(self) -> None:
        self.screen.fill(COLOR_BACKGROUND)
        screen_w, screen_h = self.screen.get_size()
        image_rect = self.background_img.get_rect()
        view_rect = pygame.Rect(
            self.camera_offset.x,
            self.camera_offset.y,
            screen_w / self.zoom_level,
            screen_h / self.zoom_level
        )
        clipped_rect = view_rect.clip(image_rect)
        if clipped_rect.width > 0 and clipped_rect.height > 0:
            visible_bg = self.background_img.subsurface(clipped_rect)
            visible_mask = self.editable_mask.subsurface(clipped_rect)
            dest_rect = pygame.Rect(
                (clipped_rect.x - self.camera_offset.x) * self.zoom_level,
                (clipped_rect.y - self.camera_offset.y) * self.zoom_level,
                clipped_rect.width * self.zoom_level,
                clipped_rect.height * self.zoom_level
            )
            scaled_bg = pygame.transform.smoothscale(visible_bg, dest_rect.size)
            scaled_mask = pygame.transform.scale(visible_mask, dest_rect.size)
            self.screen.blit(scaled_bg, dest_rect)
            self.screen.blit(scaled_mask, dest_rect)
        mouse_pos = pygame.mouse.get_pos()
        pygame.draw.circle(self.screen, COLOR_CURSOR, mouse_pos, self.brush_size, width=1)
        pygame.display.flip()


def get_paths_via_args_or_dialog():
    """
    Parses CLI arguments. If missing, launches Tkinter dialogs to ask the user.
    """
    parser = argparse.ArgumentParser(description="Launch Mask Editor GUI.")
    parser.add_argument("--images", help="Path to folder containing source TIF images.")
    parser.add_argument("--masks", help="Path to folder containing existing PNG masks.")
    parser.add_argument("--output", help="Path to folder to save edited masks.")
    
    args = parser.parse_args()

    # If all args are provided via CLI, return them
    if args.images and args.masks and args.output:
        return args.images, args.masks, args.output

    # Otherwise, fallback to GUI dialogs
    print("Arguments not fully provided. Launching directory selector...")
    root = tk.Tk()
    root.withdraw()
    
    tif_folder = args.images or filedialog.askdirectory(title="Select Source Images (TIF)")
    if not tif_folder: return None, None, None
    
    mask_folder = args.masks or filedialog.askdirectory(title="Select Existing Masks (PNG)")
    if not mask_folder: return None, None, None

    output_folder = args.output or filedialog.askdirectory(title="Select Output Folder")
    if not output_folder: return None, None, None

    return tif_folder, mask_folder, output_folder


def main() -> None:
    tif_folder, mask_folder, output_folder = get_paths_via_args_or_dialog()
    
    if not tif_folder:
        print("Selection cancelled.")
        return

    try:
        editor = MaskEditor(tif_folder, mask_folder, output_folder)
        editor.run()
    except Exception as e:
        print(f"Error: {e}")
        input("Press Enter to exit...")

if __name__ == '__main__':
    main()