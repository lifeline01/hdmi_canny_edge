# V1 调试版构建说明（2026-11-01）

## 本次配置

- `USE_DEBUG=1`，启用手动 `debug_edb_top`，提供 VIO/LA；
- Efinity Debugger `auto_instantiation=off`，避免重复插入第二个调试核；
- 调试核继续使用 `jtag_inst1`；
- 旧构建输出已移动到工程根目录的 `_pre_debug_build_20261101`，不能作为本次源码对应的比特流提交。

## 目录调整

以下配置/数据从 `doc/` 移动到 `config/`：

```text
package_settings.xml
Panel_1080p_reg.mem
yuvpattern_mif.memh
```

## RTL和约束修改

- AXI ID宽度统一为6位；
- VIC、音频N/CTS、HDMI时序参数使用固定位宽；
- 未使用的DDR调试输出显式留空，不再生成隐式1位网络；
- 帧缓存burst长度、FIFO计数和bank地址位宽参数匹配；
- JTAG SDC启用`jtag_inst1`的保守10 MHz分析时钟；
- 删除未生成的`jtag_inst2_autodbg`约束。

## 调试核WNS修复

启用LA后，报告中的最差路径为`jtag_inst1_TCK → vid_clk_dvi2`，终点位于LA Trigger Skipper，Slack为-4.247 ns。该核心内部已经包含CDC同步结构，原SDC只把JTAG与MIPI接收时钟声明为互斥，没有把JTAG与视频时钟声明为异步。现增加`jtag_inst1_TCK`到全部功能时钟的异步时钟组，避免对调试核心的CDC路径做错误的同步时序分析。

## 构建要求

从当前 V1 目录重新执行：

```text
Synthesis -> Place & Route -> Generate Bitstream
```

构建完成后必须重新检查：

1. WNS大于0；
2. 模块层级中存在`debug_edb_top_inst`；
3. 无模块缺失或综合错误；
4. 音频和视频端口宽度告警已消除；
5. 模式0～4、五目标识别和VIO/LA均重新上板验证。
