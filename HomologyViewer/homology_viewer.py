import sys
import os
import json
import tkinter as tk
from tkinter import ttk
import numpy as np
import glob
import PIL
import argparse
from PIL import Image, ImageTk, ImageOps
from matplotlib import cm
from collections import namedtuple

# The global Tk object
root = None

# Make a simple struct to store delineation id data, and define a function that creates a list from the json hierarchy
DelineationId = namedtuple("DelineationId", "id acronym fullname parent_id")
def delineation_ids_from_hierarchy(hier):
    dids = []
    nodes = hier['nodes']
    
    for i in range(len(nodes)):
        n = nodes[i]
        for chi in n.get('children',[]):
            nodes[chi]['parent_id'] = i
    
    for i in range(len(nodes)):
        n = nodes[i]
        acro = n['acronym']
        fullname = n.get('fullname',acro)
        parent_id = n.get('parent_id',-1)
        dids.append( DelineationId(i, acro, fullname, parent_id ))
    return dids
                    
def delineation_find_by_id( dids, id ):
    return next((x for x in dids if x.id == id), None)
                    
def delineation_find_by_acronym( dids, acronym ):
    return next((x for x in dids if x.acronym == acronym), None)
                    
def delineation_find_by_fullname( dids, fullname ):
    return next((x for x in dids if x.fullname == fullname), None)

## HEATMAP RELATED
# 256 rows x 4 columns
jetcolors = np.asarray([ cm.jet(i) for i in range(256)])

# x:      numpy array with values [0,1]
# return: numpy array with values [0, 255]
def heatmap_r( x ):
    #return (255*x).astype( int )
    #return (cm.jet(int(255*x))[0]*255).astype(int)
    return (jetcolors[:,0][(255*x).astype( int )] * 255).astype(int)

def heatmap_g( x ):
    #return np.zeros(x.shape, dtype = int)
    return (jetcolors[:,1][(255*x).astype( int )] * 255).astype(int)

def heatmap_b( x ):
    #return np.zeros(x.shape, dtype = int)
    return (jetcolors[:,2][(255*x).astype( int )] * 255).astype(int)

def cancel_color( c, row_is_col ):
    return ( c[0], c[1], c[2], 255 if row_is_col else 0)
    
def is_float( s ):
    try:
        v = float(s)
    except ValueError:
        return False
    return True

# x:      numpy array with values [0,1]
# k:      numpy array with values [0,3], representing the component: r,g,b or a
# return: uint8 numpy array with values [0, 255]
def heatmap_for_component( x, k ):
    m = heatmap_r(x) * (k == 0) + \
        heatmap_g(x) * (k == 1) + \
        heatmap_b(x) * (k == 2) + \
        255 * (k == 3)
    return m.astype(np.uint8)

def delineation_name_to_color( name ):
    # Colors as in paper
    names_to_colors = {
        "Isocortex" : "#00aee2",
        "OlfactoryAreas" : "#270c0e",
        "Hippocampus" : "#ea4f96",
        "CorticalSubplate" : "#ffe295",
        "Striatum" : "#00562b",
        "Pallidum" : "#0c4597",
        "Thalamus" : "#6cbfa5",
        "Hypothalamus" : "#f7c4dc",
        "Midbrain" : "#aa5017",
        "Pons" : "#dada00",
        "Medulla" : "#eb5e7d",
        "Cerebellum" : "#004f56",
    }
    return names_to_colors[name]
    
def rgb_to_hex(rgb):
    return '#%02x%02x%02x' % rgb
    
def hex_to_rgb(hex):
    return tuple(int(hex[i:i+2], 16) for i in (1, 3, 5))
    
def invert_hexcode( hexcode ):
    rgb = hex_to_rgb(hexcode)
    rgb2 = (255-rgb[0], 255-rgb[1],255-rgb[2])
    return rgb_to_hex(rgb2)

class Matrix:
    """
        datafile:
            first row is groupname_nodename
    """
    def __init__(self, id, filename):
        print('Loading similarity data file ',filename)
        # self.id = os.path.basename(filename).rsplit('_',1)[1][:-4]
        self.id = id
        assert( os.path.isfile(filename))
        csv_data = [ line.strip('\r\n\t ').split('\t') for line in open(filename, 'rt').readlines()]
        regions = csv_data[0]
        has_labels = not is_float(csv_data[1][0])
        data_row_start = 2 if has_labels else 1
        self.names = csv_data[1] if has_labels else regions
        self.matrix = np.asarray(csv_data[data_row_start:], dtype=np.float32)
        self.acronyms = [r.split('_',1)[1] if '_' in r else r for r in regions]
        
        # Region groups only if we do have them
        self.regiongroups = [] # list of (name, offset, num)
        if '_' in regions[0]:
            last_regiongroup = None
            offset = 0
            for i in range(len(regions)):
                rg = regions[i].split('_')[0]
                if rg != last_regiongroup:
                    if last_regiongroup:
                        self.regiongroups.append( (rg, offset, i-offset))
                    last_regiongroup = rg
                    offset = i
            self.regiongroups.append( (last_regiongroup, offset, len(regions)-offset))
            
class Mask:
    def __init__(self, id, filename):
        self.id = id
        self.img = PIL.Image.open(filename)

# Lazy load of masks and matrices -- access via get() functions
_masks = {}
_matrices = {}
def get_mask( key ):
    m = _masks[key]
    if not isinstance(m, Mask):
        m = Mask(key, m)
        _masks[key] = m
    return m

def get_matrix( key ):
    m = _matrices[key]
    if not isinstance(m, Matrix):
        m = Matrix(key, m)
        _matrices[key] = m
    return m

       
class SavedHighlightData:
    def __init__(self, ppc):
        self.colors = []
        self.coords = None
        self.ppc = ppc
    
    def save(self, px, row, col, dims):
        ppc = self.ppc
        self.colors = []
        i0 = row *ppc
        i1 = i0+ppc
        for i in range(i0,i1):
            for j in range(dims[0]):
                self.colors.append(px[i,j])
        i0 = col *ppc
        i1 = i0+ppc
        for i in range(i0,i1):
            for j in range(dims[1]):
                self.colors.append(px[j,i])
        self.coords = (row,col)
        #print("Saved ",len(self.colors))
    
    def restore(self, px, dims):
        if self.coords:
            ppc = self.ppc
            row,col = self.coords
            #print("Restoring ",len(self.colors))
            i0 = row *ppc
            i1 = i0+ppc
            o = 0
            for i in range(i0,i1):
                for j in range(dims[0]):
                    px[i,j] = self.colors[o]
                    o += 1
            i0 = col *ppc
            i1 = i0+ppc
            for i in range(i0,i1):
                for j in range(dims[1]):
                    px[j,i] = self.colors[o]
                    o += 1
            self.coords = []

class CanvasMatrix:
    def __init__(self, matrix, ppc ):
        self.ppc = ppc
        self.matrix = matrix
        matrix_dim = ppc*len(matrix.names)
        print("Matrix dim: ",matrix_dim)
        rgbamatrix = np.fromfunction( lambda i,j,k: heatmap_for_component( matrix.matrix[i // ppc,j // ppc] , k ), (matrix_dim, matrix_dim,4), dtype=int ).astype(np.uint8)
        self.imgmatrix = PIL.Image.fromarray(rgbamatrix).convert('RGBA')
        self.photomatrix = PIL.ImageTk.PhotoImage(self.imgmatrix)
        self.savedHighlightData = SavedHighlightData(ppc)

class CanvasMask:
    def __init__(self, img, matrix, dids):
        #print('Loading mask data file ',filename)
        #self.id = os.path.basename(filename).split('_',1)[0]
        #self.imgmask = PIL.Image.open(filename)
        self.matrix = matrix
        self.imgmask = img
        self.imgmask_px = self.imgmask.load()
        self.photomask = PIL.ImageTk.PhotoImage(self.imgmask)
        
        self.last_hovered_small_id = -1
        self.lut = None
        self.mask_iregions = None
        
        ar = np.asarray(self.imgmask)
        self.mask_iregions = None
        self.mask_isvalid = ar[:,:,3]  == 255
        self.mask_smallids = (ar[:,:,0] + ar[:,:,1]*256) * self.mask_isvalid
        
        self.calc_similarity_cache( matrix,dids)
    
    def calc_similarity_cache( self, matrix, dids):
        """
            Called when we update the matrix dataset
        """
        self.lut = np.arange(np.amax(self.mask_smallids) + 1)
        regions_sub = matrix.acronyms
        for small_id in range(self.lut.shape[0]):
            # find the region this small id corresponds to
            node = delineation_find_by_id(dids, small_id)
            acro = node.acronym
            region_id = regions_sub.index(acro) if acro in regions_sub else -1
            self.lut[small_id] = region_id
        self.mask_iregions = self.lut[ self.mask_smallids ]
        
        # Update mask_isvalid fro regions that are -1
        self.mask_isvalid[  self.mask_iregions == -1 ] = 0
        self.mask_iregions[ self.mask_isvalid == 0] = 0
        print("np.amax( mask_iregions) ", np.amax( self.mask_iregions))
        assert np.amax( self.mask_iregions) < len(regions_sub), "ERROR in mask_iregions"
        
    def on_hover( self, x,y ):
        """
            x,y relative to image
            get small id. if same as hovered or over empty, do nothing and return -1, else return new one
        """
        px = self.imgmask_px
        val = px[x, y]
        small_id = val[0] + val[1]*256

        lut = self.lut
        if val[3] != 255:        
            small_id = -1
        
        if self.last_hovered_small_id != small_id and small_id >= 0:
            self.last_hovered_small_id = small_id
            return small_id
        else:
            return -1
        
    def update_image(self, fun_color_from_small_id):
        """
            Called when the small ID changes
        """
        assert(False)
        pass
    

    
class Layout:
    """
        Common class that:
            initializes all viewports
            given a mouse cursor, returns maskdata (normal or thumb) and local coords
            handles clicks, e.g. swapping main <-> small
            places imagery at canvas
            updates imagery at canvas (callback, called from event function)
    """
    def create_regiongroup_rects( x0,y0, canvas, matrix, ppc):
        def create_rectangle( o, N, name, canvas, iter):
            
            color = delineation_name_to_color(name)
            print(name,o,N)
            p0x = x0 + o*ppc
            w = N*ppc -1
            p1x = p0x + w
            p0y = y0
            p1y = y0 + 10
            print(f"Creating rect {p0x} {p0y} {p1x} {p1y}")
            celem = canvas.create_rectangle( p0x, p0y, p1x, p1y, fill=color)
            canvas.tag_raise( celem)
            
            x = (p0x + p1x) >> 1
            y = (p0y + p1y) >> 1
            yoff = (iter % 3) * 15 + 15
            
            celem = canvas.create_text((x, y + yoff), text=name)
            #bbox = canvas.bbox(celem)
            #celem2 = canvas.create_rectangle( bbox[0], bbox[1], bbox[2], bbox[3], fill= color)
            #print("bbox: ", str(bbox))
            #canvas.tag_raise( celem2)
            canvas.tag_raise( celem)
        
        offset = 0
        name = None
        iter = 0
        for i in range(len(matrix.names)):
            n = matrix.names[i].split('_')[0]
            if n != name:
                if name:
                    create_rectangle(offset, i-offset, name, canvas, iter)
                    iter += 1
                name = n
                offset = i
        create_rectangle(offset, len(matrix.names)-offset, name, canvas, iter)
        #print(len(matrix.names))
        
    def __init__(self, preset, dids):
        
        max_screen_width = root.winfo_screenwidth()
        max_screen_height = root.winfo_screenheight()
        
        self.canvas = None
        self.viewports = [] # Stores ( (x,y,w,h) ,CanvasMask/Matrix, canvas mask)
        
        
        
        cur_w = 0
        cur_h = 0
        for elem in preset:
            rect = elem['rect']
            if len(rect) == 2:
                if "mask_id" in elem.keys():
                    m = get_mask(elem['mask_id'])
                    rect = (rect[0],rect[1],m.size[0], m.size[1])
                else:
                    m = get_matrix(elem['matrix_id'])
                    w = m.matrix.shape[0]
                    rect = (rect[0],rect[1],w,w)
                elem['rect'] = rect
                    
            cur_w = max(cur_w, rect[0] + rect[2])
            cur_h = max(cur_h, rect[1] + rect[3])
            
        assert cur_w <= max_screen_width, f"Can't fit desired canvas ({cur_w} {cur_h}) at given screen resolution ({max_screen_width} {max_screen_height})"
        print(f"Resolution for layout: {cur_w} {cur_h}")
        self.canvas = tk.Canvas(root,width=cur_w, height=cur_h)
        
        # Create all elements
        largest_mask_area = 0
        largest_mask_id = -1
        for elem in preset:
            obj = None
            ctext = None
            canvas_elem = None
            matrix = get_matrix(elem['matrix_id'])
            rect = elem['rect']
            if "mask_id" in elem.keys():
                m = get_mask(elem['mask_id'])
                area = rect[2] * rect[3]
                if area > largest_mask_area:
                    largest_mask_area = area
                    largest_mask_id = preset.index(elem)
                if (rect[2] != m.img.size[0]) or (rect[3] != m.img.size[1]):
                    print("Scaling image")
                    dims = (rect[2],rect[3])
                    img = Image.new('RGBA', dims, (0,0,255,0))
                    
                    # scale it so that it fits in required rect
                    scale_amt = min( rect[2] / float(m.img.size[0]) , rect[3] / float(m.img.size[1]))
                    dims2 = ( int( m.img.size[0]*scale_amt + 0.5), int( m.img.size[1]*scale_amt + 0.5))
                    img_in_scaled = m.img.resize(dims2, Image.NEAREST)
                    assert(dims2[0] == dims[0] or dims2[1] == dims[1])
                    paste_rect = (0, (dims[1] - dims2[1])>>1) if dims2[0] == dims[0] else ((dims[0] - dims2[0])>>1,0)
                    print(f"Pasting at {paste_rect[0]} {paste_rect[1]}")
                    img.paste(img_in_scaled, paste_rect)
                    
                    obj = CanvasMask( img, matrix, dids)
                    ctext = self.canvas.create_text(rect[0]+10, rect[1]+10, text= "", anchor="nw")
                    canvas_elem = self.canvas.create_image( rect[0], rect[1], anchor=tk.NW, image=obj.photomask)
            else:
                rows = matrix.matrix.shape[0]
                ppc = int(min( rect[2], rect[3]) / rows)
                assert ppc > 0, f"Can't fit matrix of size {rows} in {rect[2]} {rect[3]}"
                obj = CanvasMatrix( matrix, ppc)
                ctext = self.canvas.create_text(10, rows*ppc + 45, text= "", anchor="nw")
                canvas_elem = self.canvas.create_image( rect[0], rect[1], anchor=tk.NW, image=obj.photomatrix)
                
                Layout.create_regiongroup_rects( rect[0], rect[1] + rows*ppc, self.canvas, matrix, ppc)
                    
            self.viewports.append( (rect, obj, canvas_elem, ctext) )
        if largest_mask_id == -1:
            largest_mask_id = 0
        self.largest_mask_id = largest_mask_id
        
        #print(self.viewports)
    
    def get_viewport_coords( self, x,y ):
        # Return the viewport coords, alongside with a CanvasMask or SimData object
        for i in range(len(self.viewports)):
            vp = self.viewports[i]
            r = vp[0]
            xrel = x - r[0]
            yrel = y - r[1]
            if xrel >= 0 and yrel >= 0 and xrel < r[2] and yrel < r[3]:
                return (xrel, yrel, vp)
        return (None,None,None)


hovered_small_id = -1
hovered_small_id2 = -1
layout = None
    
# The region_id is the sequential ID, wrt the other web script. It's -1 when invalid, otherwise we can use it as an index to the node list from the json hierarchy data
def on_hovered_region_change( small_id, small_id2, region_id, region_id2, layout ):
    global hovered_small_id
    global hovered_small_id2
    
    prev_small_id = hovered_small_id
    prev_small_id2 = hovered_small_id2
    hovered_small_id = small_id    
    hovered_small_id2 = small_id2    

    # Build a mask image using vectorized ops
    if hovered_small_id >= 0:
        for vp in layout.viewports:
            if isinstance(vp[1], CanvasMask):
                maskdata = vp[1]
                matrix = maskdata.matrix
                hovered_region = maskdata.lut[hovered_small_id]
                #print(hovered_region)
                mask_iregions = maskdata.mask_iregions
                mask_isvalid = maskdata.mask_isvalid
                fvals = np.zeros( mask_iregions.shape, dtype = np.float32)
                row_data = mask_iregions
                col_data = np.ones( mask_iregions.shape, dtype = np.int32)*hovered_region
                fvals = matrix.matrix[row_data, col_data]
                imgdata = np.zeros( (fvals.shape[0],fvals.shape[1],4), dtype = np.uint8)
                for k in range(4):
                    imgdata[:,:,k] = heatmap_for_component( fvals, mask_isvalid*k + 3*(1-mask_isvalid)) # if invalid, pretend all components are alpha component, therefore 255
                maskdata.imgmask = PIL.Image.fromarray(imgdata)
                maskdata.photomask = PIL.ImageTk.PhotoImage( maskdata.imgmask )
                canvas_mask = vp[2]
                layout.canvas.itemconfig(canvas_mask, image = maskdata.photomask)
    
    for vp in layout.viewports:
        if isinstance(vp[1], CanvasMatrix):
            #matrix = vp[1].matrix
            ppc = vp[1].ppc
            matrix = vp[1].matrix
            
            # Matrix: invert color in relevant col/row
            imgmatrix = vp[1].imgmatrix
            px = imgmatrix.load()
            vp[1].savedHighlightData.restore(px, imgmatrix.size)
            
            node = delineation_find_by_id(dids, small_id)
            #region_id = -1
            if node:
                acro = node.acronym
                regions_sub = matrix.acronyms
                #region_id = regions_sub.index(acro) if acro in regions_sub else -1
            
                #node = delineation_find_by_id(dids, small_id2)
                #acro = node.acronym
                #regions_sub = matrix.acronyms
                #region_id2 = regions_sub.index(acro) if acro in regions_sub else -1

                vp[1].savedHighlightData.save(px, region_id, region_id2, imgmatrix.size)
                i0 = region_id2 *ppc
                i1 = i0+ppc
                for i in range(i0,i1):
                    for j in range(imgmatrix.size[0]):
                        px[j,i] = cancel_color(px[j,i], region_id == j//ppc)
                
                i0 = region_id *ppc
                i1 = i0+ppc
                for i in range(i0,i1):                
                    for j in range(imgmatrix.size[1]):
                        px[i,j] = cancel_color(px[i,j], region_id2 == j//ppc)

            vp[1].photomatrix = PIL.ImageTk.PhotoImage( imgmatrix )
            layout.canvas.itemconfig(vp[2], image = vp[1].photomatrix)

########################
# PROGRAM START ########
########################
root = tk.Tk()
root.title('Homology Viewer')
w = root.winfo_screenwidth()
h = root.winfo_screenheight()-70
root.geometry("%dx%d+0+0" % (w, h))

json_config = json.load( open(os.path.dirname(sys.argv[0]) + "/config.json",'rt'))

# Read hierarchy, masks and matrices
dids_fname = json_config['regions_filename']
dids = delineation_ids_from_hierarchy( json.load( open(dids_fname,'rt')))
_masks = json_config['masks']
_matrices = json_config['matrices']

preset = None 
if len(sys.argv) > 1:
    parser = argparse.ArgumentParser(description='View one or more datasets, using image mode (--image), matrix mode (--matrix) or both (default, no arguments needed)', epilog="Available datasets are 1W 2W 3W 1M 2M 3M 6M 12M 18M")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("-i", "--image", help="image mode ONLY for loaded datasets",action="store_true")
    group.add_argument("-m", "--matrix", help="matrix mode ONLY for loaded datasets",action="store_true")
    parser.add_argument('-d', "--datasets", help="list of dataset names", nargs='+')
    args = parser.parse_args()
    
    image_mode = args.image
    matrix_mode = args.matrix
    if not (image_mode or matrix_mode):
        image_mode = True
        matrix_mode = True
    
    max_datasets_per_row = 2 if len(args.datasets) <= 4 else 3
    num_rows = (len(args.datasets) // max_datasets_per_row) + 1
    num_cols = min( len(args.datasets), max_datasets_per_row)
    
    w_per_cell = w // num_cols
    h_per_cell = h // num_rows
    
    wm = 300 if matrix_mode else 0
    wi = w_per_cell - (wm + 10)
    hi = h_per_cell
    
    preset = []
    for iGroup in range(len(args.datasets)):
        row = iGroup // num_cols
        col = iGroup % num_cols
        ycur = row * h_per_cell
        xcur = col * w_per_cell
        
        print(row,col)
        
        dataset = args.datasets[iGroup]
        if image_mode:
            ri =  [xcur, ycur, wi, hi]
            xcur += wi
            d = { "matrix_id" : dataset, "mask_id" : dataset, "rect" : ri}
            preset.append(d)
        if matrix_mode:
            rm =  [xcur, ycur, wm, wm]
            xcur += wm
            d = { "matrix_id" : dataset, "rect" : rm}
            preset.append(d)
            
    #print(w_per_group)

layout = None

presets = list(json_config['presets'].keys())

topframe = tk.Frame(height=20)
tk.Label(topframe, text="Colormap [0-1]:  ").pack(side="left")
# create colormap canvas and fill with the colors
cmap_canvas = tk.Canvas(topframe, width=256, height=20)
cmap_canvas.pack(side="left")
vals01 = np.expand_dims( np.repeat( np.expand_dims(np.linspace(0,1, num=256),0), repeats=20, axis=0 ), 2)
array = np.concatenate( (heatmap_r(vals01), heatmap_g(vals01), heatmap_b(vals01)), 2).astype(np.uint8)
arrayimg = Image.fromarray(array)
img =  ImageTk.PhotoImage(image=arrayimg)
cmap_canvas.create_image(0,0,anchor = 'nw', image=img)

# Conditionally add the combobox with the presets
if not preset:
    tk.Label(topframe, text="  Preset: ").pack(side="left")
    combo = ttk.Combobox(topframe, values=presets)
    def onPresetChanged(event):
        global layout
        global combo
        if layout:
            layout.canvas.delete('all')
            layout.canvas.pack_forget()
        layout = Layout( json_config['presets'][combo.get()], dids)
        layout.canvas.pack()
        layout.canvas.bind("<Motion>", moved)

    combo.current( 0)
    combo.pack()
    combo.bind("<<ComboboxSelected>>", onPresetChanged)

    layout = Layout( json_config['presets'][presets[0]], dids)
else:
    
    layout = Layout( preset, dids)
topframe.pack()
layout.canvas.pack()
tk.Label('').pack()

def moved(event):
    global hovered_region
    text = ""
    x,y,vp = layout.get_viewport_coords( event.x, event.y)
    if vp:
        region_id = -1
        small_id = -1
        if isinstance( vp[1], CanvasMask):
            maskdata = vp[1]
            px = maskdata.imgmask_px
            val = px[x, y]
            small_id = val[0] + val[1]*256 if val[3] == 255 else -1
                
            node = delineation_find_by_id(dids, small_id)
            if node:
                regions_sub = vp[1].matrix.acronyms
                acro = node.acronym
                region_id = regions_sub.index(acro) if acro in regions_sub else -1
                
            if small_id != hovered_small_id:
                on_hovered_region_change(small_id, small_id, region_id, region_id, layout )
            
        elif isinstance( vp[1], CanvasMatrix):
            ppc = vp[1].ppc
            regions = vp[1].matrix.names
            cell_x = int(x / ppc)
            cell_y = int(y / ppc)
            all_acros = [ did.acronym for did in dids]
            
            region_ids = (cell_x,cell_y) if (cell_x >= 0 and cell_y >= 0 and cell_x < len(regions) and cell_y < len(regions)) else (-1,-1)
            
            #print(f"Searching {simdata.acronyms[region_id]} in {str(all_acros)}")
            acro0 = vp[1].matrix.acronyms[region_ids[0]]
            acro1 = vp[1].matrix.acronyms[region_ids[1]]
            
            small_ids =  (all_acros.index(acro0) if acro0 in all_acros else -1,
                          all_acros.index(acro1) if acro1 in all_acros else -1)
            region_id = region_ids[0]
            small_id = small_ids[0]
            
            if small_ids[0] != hovered_small_id or small_ids[1] != hovered_small_id2:
                on_hovered_region_change(small_ids[0], small_ids[1], region_ids[0], region_ids[1], layout)
            
        else:
            assert(False)
            
        for vp2 in layout.viewports:
            if isinstance( vp2[1], CanvasMask):
                layout.canvas.itemconfigure(vp2[3], text= f"Dataset: {vp2[1].matrix.id}\n")
                layout.canvas.tag_raise( vp2[3])
        
        if region_id >= 0 and small_id >= 0:
            print(region_id, small_id)
            matrix = vp[1].matrix
            regions = vp[1].matrix.names
            text = f"Dataset: {matrix.id}\n"
            node = delineation_find_by_id( dids, small_id )
            text += f"Region: {node.fullname}\n"
            sorted_indices = np.argsort(matrix.matrix[region_id,:]).tolist()
            sorted_indices.reverse()
            text += "Most similar to: \n" + "\n".join([ f"  {regions[sorted_indices[i]]} ({matrix.matrix[region_id, sorted_indices[i]]})" for i in range(1,10)])
            if layout.largest_mask_id >= 0:
                vp = layout.viewports[layout.largest_mask_id]
                layout.canvas.itemconfigure(vp[3], text=text)
                layout.canvas.tag_raise( vp[3])


layout.canvas.bind("<Motion>", moved)



root.mainloop()