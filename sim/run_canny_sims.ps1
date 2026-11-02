$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$iverilog = 'D:\iverilog\bin\iverilog.exe'
$vvp = 'D:\iverilog\bin\vvp.exe'
if (-not (Test-Path -LiteralPath $iverilog)) {
    $iverilog = (Get-Command iverilog).Source
    $vvp = (Get-Command vvp).Source
}
$ramModel = 'E:\YuHongwei\Project\FPGA\Ti60F225I3\_edge\sim\gray_line_ram_model.v'

Push-Location $root
try {
    & $iverilog -g2012 -s tb_ui_modes -o 'sim\tb_ui_modes.vvp' `
        'sim\tb_ui_modes.v' 'rtl\image\ui_control.v'
    if ($LASTEXITCODE -ne 0) { throw 'UI mode compilation failed' }
    & $vvp 'sim\tb_ui_modes.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'UI mode simulation failed' }

    & $iverilog -g2012 -s tb_rgb_saturation -o 'sim\tb_rgb_saturation.vvp' `
        'sim\tb_rgb_saturation.v' 'rtl\image\rgb_saturation.v'
    if ($LASTEXITCODE -ne 0) { throw 'saturation test compilation failed' }
    & $vvp 'sim\tb_rgb_saturation.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'saturation test simulation failed' }

    & $iverilog -g2012 -s tb_median3x3 -o 'sim\tb_median3x3.vvp' `
        'sim\tb_median3x3.v' 'rtl\image\median3x3.v'
    if ($LASTEXITCODE -ne 0) { throw 'median test compilation failed' }
    & $vvp 'sim\tb_median3x3.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'median test simulation failed' }

    & $iverilog -g2012 -s tb_canny_pipeline -o 'sim\tb_canny_pipeline.vvp' `
        'sim\tb_canny_pipeline.v' 'rtl\image\canny_pipeline.v' 'rtl\image\median3x3.v' `
        'rtl\image\gray_window_3x3.v' 'rtl\image\sobel3x3.v' $ramModel
    if ($LASTEXITCODE -ne 0) { throw 'tb_canny_pipeline compilation failed' }
    & $vvp 'sim\tb_canny_pipeline.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'tb_canny_pipeline simulation failed' }

    & $iverilog -g2012 -s tb_edge_canny_integration -o 'sim\tb_edge_canny_integration.vvp' `
        'sim\tb_edge_canny_integration.v' 'rtl\image\edge_detect_1ppc.v' `
        'rtl\image\canny_pipeline.v' 'rtl\image\median3x3.v' 'rtl\image\rgb888_to_gray.v' `
        'rtl\image\rgb_saturation.v' `
        'rtl\image\gray_window_3x3.v' 'rtl\image\sobel3x3.v' `
        'rtl\image\video_stream_sync.v' 'rtl\true_dual_port_ram.v' `
        'rtl\image\shape_edge_detector.v' `
        'rtl\image\shape_tracker.v' 'rtl\image\shape_overlay.v' $ramModel
    if ($LASTEXITCODE -ne 0) { throw 'integration test compilation failed' }
    & $vvp 'sim\tb_edge_canny_integration.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'integration test simulation failed' }

    & $iverilog -g2012 -s tb_shape_tracker -o 'sim\tb_shape_tracker.vvp' `
        'sim\tb_shape_tracker.v' 'rtl\image\shape_tracker.v'
    if ($LASTEXITCODE -ne 0) { throw 'shape tracker compilation failed' }
    & $vvp 'sim\tb_shape_tracker.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'shape tracker simulation failed' }

    & $iverilog -g2012 -s tb_shape_tracker_multi -o 'sim\tb_shape_tracker_multi.vvp' `
        'sim\tb_shape_tracker_multi.v' 'rtl\image\shape_tracker.v'
    if ($LASTEXITCODE -ne 0) { throw 'multi-target tracker compilation failed' }
    & $vvp 'sim\tb_shape_tracker_multi.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'multi-target tracker simulation failed' }

    & $iverilog -g2012 -s tb_shape_edge_detector -o 'sim\tb_shape_edge_detector.vvp' `
        'sim\tb_shape_edge_detector.v' 'rtl\image\shape_edge_detector.v' `
        'rtl\true_dual_port_ram.v'
    if ($LASTEXITCODE -ne 0) { throw 'edge contour detector compilation failed' }
    & $vvp 'sim\tb_shape_edge_detector.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'edge contour detector simulation failed' }

    & $iverilog -g2012 -s tb_shape_edge_rotation -o 'sim\tb_shape_edge_rotation.vvp' `
        'sim\tb_shape_edge_rotation.v' 'rtl\image\shape_edge_detector.v' `
        'rtl\true_dual_port_ram.v'
    if ($LASTEXITCODE -ne 0) { throw 'rotation classifier compilation failed' }
    & $vvp 'sim\tb_shape_edge_rotation.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'rotation classifier simulation failed' }

    & $iverilog -g2012 -s tb_shape_overlay -o 'sim\tb_shape_overlay.vvp' `
        'sim\tb_shape_overlay.v' 'rtl\image\shape_overlay.v'
    if ($LASTEXITCODE -ne 0) { throw 'shape overlay compilation failed' }
    & $vvp 'sim\tb_shape_overlay.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'shape overlay simulation failed' }

    & $iverilog -g2012 -s tb_edge_shape_mode -o 'sim\tb_edge_shape_mode.vvp' `
        'sim\tb_edge_shape_mode.v' 'rtl\image\edge_detect_1ppc.v' `
        'rtl\image\canny_pipeline.v' 'rtl\image\median3x3.v' 'rtl\image\rgb888_to_gray.v' `
        'rtl\image\rgb_saturation.v' 'rtl\image\gray_window_3x3.v' `
        'rtl\image\sobel3x3.v' 'rtl\image\video_stream_sync.v' `
        'rtl\true_dual_port_ram.v' 'rtl\image\shape_edge_detector.v' `
        'rtl\image\shape_tracker.v' `
        'rtl\image\shape_overlay.v' $ramModel
    if ($LASTEXITCODE -ne 0) { throw 'edge mode 4 compilation failed' }
    & $vvp 'sim\tb_edge_shape_mode.vvp'
    if ($LASTEXITCODE -ne 0) { throw 'edge mode 4 simulation failed' }
}
finally {
    Pop-Location
}
