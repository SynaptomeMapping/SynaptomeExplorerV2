This repository contains the binaries for the Synaptome Explorer V2 and Homology Viewer visualization software.

# Synaptome Explorer V2

Synaptome Explorer is used for in-depth exploration of the synaptome of a single brain section. It enables interactive visualization of the brain region in full resolution, as captured by the microscope, and uses overlays to display the synaptic puncta and all their parameters, providing users with extensive parameter range filters to display subsets of puncta accordingly. The granularity of the data visualization is at the level of individual puncta, as users can click on a single punctum and see its parameters. An additional feature is region-based and tile-based filtered puncta statistics, where users can set up parameter range filters, select a combination of regions or subregions and interactively calculate statistics, such as mean intensity, mean size and density, visualized over the corresponding regions or tiles, respectively.

The application executable is synaptome_explorer_v2.exe

The datasets can be found in: [TBD]

The first time the application is executed with a particular dataset, intermediate files are generated, that will be used to accelerate future runs. The generation time of these intermediate files can vary from several seconds to a few minutes. The intermediate files are placed in a folder called "RuntimeCache", under the working directory at the time of execution.

For further description and how to use instructions, please refer to synaptome_explorer_v2.pdf

# Homology Viewer

Homology Viewer is a tool that enables interactive visualization of similarity matrices whose values correspond to brain regions/subregions, puts the data in a spatial context and allows simultaneous visualization of different brain section data that are delineated similarly. Users can hover over a brain region or a similarity matrix entry and immediately see how that region is similar to all other regions using a heatmap. Likewise, when using multiple brain regions, users can visualize how a hovered-over region in a brain section is similar to all other regions in all other brain sections. Thus, the tool makes the results of similarity matrices visually accessible owing to the direct mapping of the data on the brain section(s).

To run Homology Viewer, you need python 3 and the following libraries installed:
* tkinter
* PIL
* numpy
* matplotlib