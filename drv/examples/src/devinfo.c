/**
 * @file devinfo.c
 * @brief Device Info Demonstration
 * @author Dmitry Matyunin (https://github.com/mcjtag)
 * @date 20.03.2021
 * @copyright
 *  Copyright (c) 2021 Dmitry Matyunin
 *  Permission is hereby granted, free of charge, to any person obtaining a copy
 *  of this software and associated documentation files (the "Software"), to deal
 *  in the Software without restriction, including without limitation the rights
 *  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *  copies of the Software, and to permit persons to whom the Software is
 *  furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice shall be included in
 *  all copies or substantial portions of the Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *  THE SOFTWARE.
 */

#include <stdio.h>
#include "aub.h"

static struct aub_device_info dev_info;

int main(void)
{
	int res, dev_count;

	res = aub_init();
	printf("Init: %s\n", res ? "failed" : "success");
	if (res)
		return -1;

	dev_count = aub_get_device_count();
	printf("Device Count: <%d>\n", dev_count);
	if (dev_count < 0) {
		aub_deinit();
		return -1;
	}

	for (int i = 0; i < dev_count; i++) {
		aub_get_device_info(i, &dev_info);
		printf("Device <%d> Info:\n", i);
		printf(" > DEVNUM:  %04X\n", dev_info.devnum);
		printf(" > BUSNUM:  %02X\n", dev_info.busnum);
		printf(" > DEVADDR: %02X\n", dev_info.devaddr);
		printf(" > STR.MANUFACTURER:           %s\n", dev_info.str.manufacturer);
		printf(" > STR.PRODUCT:                %s\n", dev_info.str.product);
		printf(" > STR.SERIAL:                 %s\n", dev_info.str.serial);
		printf(" > CFG.SPEED:                  %s\n", dev_info.config.speed ? "high-speed" : "full-speed");
		printf(" > CFG.MODE:                   %s\n", dev_info.config.mode ? "packet" : "stream");
		printf(" > CFG.CHAN[IN].ENABLED:       %s\n", dev_info.config.chan[AUB_CHAN_IN].enabled ? "yes" : "no");
		printf(" > CFG.CHAN[IN].WIDTH:         %d\n", dev_info.config.chan[AUB_CHAN_IN].width);
		printf(" > CFG.CHAN[IN].ENDIANESS:     %s\n", dev_info.config.chan[AUB_CHAN_IN].endianess ? "big-endian" : "little-endian");
		printf(" > CFG.CHAN[IN].FIFO_ENABLED:  %s\n", dev_info.config.chan[AUB_CHAN_IN].fifo_enabled ? "yes" : "no");
		printf(" > CFG.CHAN[IN].FIFO_MODE:     %s\n", dev_info.config.chan[AUB_CHAN_IN].fifo_mode ? "packet" : "stream");
		printf(" > CFG.CHAN[IN].FIFO_DEPTH:    %d\n", dev_info.config.chan[AUB_CHAN_IN].fifo_depth);
		printf(" > CFG.CHAN[OUT].ENABLED:      %s\n", dev_info.config.chan[AUB_CHAN_OUT].enabled ? "yes" : "no");
		printf(" > CFG.CHAN[OUT].WIDTH:        %d\n", dev_info.config.chan[AUB_CHAN_OUT].width);
		printf(" > CFG.CHAN[OUT].ENDIANESS:    %s\n", dev_info.config.chan[AUB_CHAN_OUT].endianess ? "big-endian" : "little-endian");
		printf(" > CFG.CHAN[OUT].FIFO_ENABLED: %s\n", dev_info.config.chan[AUB_CHAN_OUT].fifo_enabled ? "yes" : "no");
		printf(" > CFG.CHAN[OUT].FIFO_MODE:    %s\n", dev_info.config.chan[AUB_CHAN_OUT].fifo_mode ? "packet" : "stream");
		printf(" > CFG.CHAN[OUT].FIFO_DEPTH:   %d\n", dev_info.config.chan[AUB_CHAN_OUT].fifo_depth);
		printf("\n");
	}

	aub_deinit();

	return 0;
}
