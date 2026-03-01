import struct

def create_ico(filename, size=32):
    """Create a minimal valid Windows ICO file"""
    # ICO header
    header = struct.pack('<HHH', 0, 1, 1)  # Reserved, Type (1=icon), Count (1 image)
    
    # Image directory entry
    width = size if size < 256 else 0  # 0 means 256
    height = size * 2 if size < 256 else 0  # Double for ICO (height includes mask)
    colors = 0  # No color table
    reserved = 0
    planes = 1
    bpp = 32  # 32-bit (RGBA)
    
    # Create simple RGBA bitmap data (solid blue square)
    pixel_data = b''
    mask_data = b''
    
    for y in range(size):
        row = b''
        for x in range(size):
            # BGRA format (blue color)
            row += b'\x66\x7E\xEA\xFF'  # Blue-ish color with alpha
        # Pad row to 4-byte boundary
        padding = (4 - (size * 4) % 4) % 4
        row += b'\x00' * padding
        pixel_data += row
        # Mask: one bit per pixel, all opaque (0)
        mask_bytes = ((size + 7) // 8) * size
        mask_data = b'\x00' * mask_bytes
    
    bitmap_size = len(pixel_data) + len(mask_data)
    bitmap_offset = 40 + 16  # BITMAPINFOHEADER + colors
    
    # Directory entry (16 bytes): width, height, colors, reserved, planes, bpp, size, offset
    dir_entry = struct.pack('<BBBBHHII',
        width, height, colors, reserved, planes, bpp,
        bitmap_size, bitmap_offset)
    
    # BITMAPINFOHEADER
    bitmap_header = struct.pack('<IIIHHIIIIII',
        40,  # Header size
        size, size * 2,  # Width, Height
        1,  # Planes
        bpp,  # Bit count
        0, 0, 0, 0, 0, 0)  # Compression, size, x/y pixels per meter, colors, important colors
    
    # Write ICO file
    with open(filename, 'wb') as f:
        f.write(header)
        f.write(dir_entry)
        f.write(bitmap_header)
        f.write(pixel_data)
        f.write(mask_data)
    
    print(f'Created {filename}')

if __name__ == '__main__':
    create_ico('icon.ico', 32)
    print('Done!')
