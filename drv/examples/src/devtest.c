/**
 * @file devinfo.c
 * @brief Device Test Demonstration
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
#include <time.h>
#include "aub.h"

#define TX_BUFSIZE		512
#define RX_BUFSIZE		512
#define REPEATS			10000

static unsigned char tx_data[TX_BUFSIZE];
static unsigned char rx_data[RX_BUFSIZE];

static aub_device_t dev;

int main(void)
{
	int dev_count, res, sres, rres;
	int pkt_err, pkt_send, pkt_recv;
	double tx_sec, rx_sec, tx_vol, rx_vol;
	struct timeval tv_tx_start, tv_tx_end, tv_rx_start, tv_rx_end;
	unsigned long tx_start, tx_end, rx_start, rx_end;

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

	pkt_send = 0;
	pkt_recv = 0;
	pkt_err = 0;
	tx_sec = 0.0;
	rx_sec = 0.0;
	if (!aub_open(&dev)) {
		printf("Testing...\n");
		for (int r = 0; r < REPEATS; r++) {
			for (int i = 0; i < TX_BUFSIZE; i++)
				tx_data[i] = (unsigned int)i + r;
			mingw_gettimeofday(&tv_tx_start, NULL);
			sres = aub_send(dev, tx_data, TX_BUFSIZE);
			mingw_gettimeofday(&tv_tx_end, NULL);
			tx_start = 1000000 * tv_tx_start.tv_sec + tv_tx_start.tv_usec;
			tx_end = 1000000 * tv_tx_end.tv_sec + tv_tx_end.tv_usec;
			mingw_gettimeofday(&tv_rx_start, NULL);
			rres = aub_recv(dev, rx_data, RX_BUFSIZE);
			mingw_gettimeofday(&tv_rx_end, NULL);
			rx_start = 1000000 * tv_rx_start.tv_sec + tv_rx_start.tv_usec;
			rx_end = 1000000 * tv_rx_end.tv_sec + tv_rx_end.tv_usec;
			if (sres < 0) {
				pkt_err++;
				continue;
			}
			pkt_send++;
			tx_sec += (double)(tx_end - tx_start);
			if (rres < 0) {
				pkt_err++;
				continue;
			}
			pkt_recv++;
			rx_sec += (double)(rx_end - rx_start);
			for (int i = 0; i < TX_BUFSIZE; i++) {
				if (tx_data[i] != rx_data[i]) {
					pkt_err++;
					break;
				}
			}
		}

		tx_sec /= 1000000.0;
		rx_sec /= 1000000.0;
		tx_vol = (double)TX_BUFSIZE * pkt_send * 8.0 / (1024.0 * 1024.0);
		rx_vol = (double)RX_BUFSIZE * pkt_recv * 8.0 / (1024.0 * 1024.0);
		printf("Packets:\n");
		printf("   Sent:     %d\n", pkt_send);
		printf("   Received: %d\n", pkt_recv);
		printf("   Errors:   %d\n", pkt_err);
		printf("Amount:\n"
			   "   Tx = %.2f Mbits\n"
			   "   Rx = %.2f Mbits\n", tx_vol, rx_vol);
		printf("Speed :\n"
			   "   Tx = %.2f Mbps\n"
			   "   Rx = %.2f Mbps\n", tx_vol / tx_sec, rx_vol / rx_sec);
		aub_close(dev);
	} else {
		printf("Device open error!\n");
	}

	aub_deinit();

	return 0;
}
