/**
 * @file aub.c
 * @brief AXIS USB Bridge
 * @author Dmitry Matyunin (https://github.com/mcjtag)
 * @date: 20.03.2021
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

#include <libusb.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include "list.h"
#include "aub.h"

#define VENDOR_ID	0xFACE
#define PRODUCT_ID	0x0BDE

#define INFO_SIZE	64
#define TIMEOUT		10

#define PACKETSIZE_HS	512
#define PACKETSIZE_FS	64

enum REQUEST_TYPE {
	REQUEST_TYPE_IN = LIBUSB_ENDPOINT_IN | LIBUSB_REQUEST_TYPE_VENDOR,
	REQUEST_TYPE_OUT = LIBUSB_ENDPOINT_OUT | LIBUSB_REQUEST_TYPE_VENDOR
};

enum BULK_ENDPOINT {
	BULK_ENDPOINT_IN = LIBUSB_ENDPOINT_IN | 1,
	BULK_ENDPOINT_OUT = LIBUSB_ENDPOINT_OUT | 1
};

enum REQUEST {
	REQUEST_CFG_GET = 0,
	REQUEST_REG_OPER = 1
};

enum REG {
	REG_TSR = 0,
	REG_TLR = 1,
	REG_RSR = 2
};

enum REG_TSR_BIT {
	REG_TSR_BIT_RDY = 1,
	REG_TSR_BIT_LST = 2
};

enum REG_RSR_BIT {
	REG_RSR_BIT_RDY = 1,
	REG_RSR_BIT_LST = 2
};

enum DATA_WIDTH {
	DATA_WIDTH_NONE = 0,
	DATA_WIDTH_8 = 1,
	DATA_WIDTH_16 = 2,
	DATA_WIDTH_32 = 3
};

struct aub_config {
	struct {
		uint16_t enabled:1;
		uint16_t width:2;
		uint16_t endianess:1;
		uint16_t fifo_enabled:1;
		uint16_t fifo_mode:1;
		uint16_t fifo_depth:5;
		uint16_t :5;
	}chan[2];
	uint16_t speed:1;
	uint16_t mode:1;
	uint16_t :14;
};

struct aub_device_str_info {
	unsigned char manufacturer[INFO_SIZE];
	unsigned char product[INFO_SIZE];
	unsigned char serial[INFO_SIZE];
};

struct aub_device {
	libusb_device *dev;
	libusb_device_handle *hdev;
	struct libusb_device_descriptor desc;
	struct aub_device_str_info info;
	struct aub_config cfg;
	unsigned char busnum;
	unsigned char devaddr;
	unsigned int devnum;
	struct list_head list;
	int width_k[2];
	int wmaxpacketsize;
};

static libusb_context *usb_ctx = NULL;
static struct aub_device *device_list = NULL;
static unsigned int device_count;

static int create_device_list(void);
static void destroy_device_list(void);
static int open_device(struct aub_device *adev);
static void close_device(struct aub_device *adev);
static inline int bulk_send(struct aub_device *adev, const unsigned char *data, uint16_t length, int *act_len);
static inline int bulk_recv(struct aub_device *adev, unsigned char *data, uint16_t length, int *act_len);
static inline int request_cfg_get(struct aub_device *adev);
static inline int request_reg_write(struct aub_device *adev, uint16_t regaddr, uint16_t regval);
static inline int request_reg_read(struct aub_device *adev, uint16_t regaddr, uint16_t *regval);

int AUB_CALL aub_init(void)
{
	if (libusb_init(&usb_ctx))
		return AUB_ERROR_LOWLEVEL;
	return create_device_list();
}

void AUB_CALL aub_deinit(void)
{
	if (usb_ctx) {
		destroy_device_list();
		libusb_exit(usb_ctx);
		usb_ctx = NULL;
	}
}

int AUB_CALL aub_get_device_count(void)
{
	if (!device_list)
		return AUB_ERROR_NOT_INITIALIZED;
	return device_count;
}

int AUB_CALL aub_get_device_info(unsigned int dev_number, struct aub_device_info *dev_info)
{
	struct aub_device *adev;
	struct list_head *pos;

	if (!device_count)
		return AUB_ERROR_NO_DEVICE_FOUND;

	list_for_each (pos, &device_list->list) {
		adev = list_entry(pos, struct aub_device, list);
		if (adev->devnum == dev_number) {
			dev_info->devnum = adev->devnum;
			dev_info->busnum = adev->busnum;
			dev_info->devaddr = adev->devaddr;
			dev_info->str.manufacturer = (char *)adev->info.manufacturer;
			dev_info->str.product = (char *)adev->info.product;
			dev_info->str.serial = (char *)adev->info.serial;
			dev_info->config.mode = adev->cfg.mode;
			dev_info->config.speed = adev->cfg.speed;
			for (int i = 0; i < 2; i++) {
				dev_info->config.chan[i].enabled = adev->cfg.chan[i].enabled;
				dev_info->config.chan[i].width = 8 * adev->width_k[i];
				dev_info->config.chan[i].endianess = adev->cfg.chan[i].endianess;
				dev_info->config.chan[i].fifo_enabled = adev->cfg.chan[i].fifo_enabled;
				dev_info->config.chan[i].fifo_mode = adev->cfg.chan[i].fifo_mode;
				dev_info->config.chan[i].fifo_depth = (1 << adev->cfg.chan[i].fifo_depth);
			}
			return AUB_SUCCESS;
		}
	}
	return AUB_ERROR_NO_DEVICE_FOUND;
}

int AUB_CALL aub_get_device_number(aub_device_t dev)
{
	struct aub_device *adev;
	struct list_head *pos;

	if (!usb_ctx)
		return AUB_ERROR_NOT_INITIALIZED;
	if (!device_list)
		return AUB_ERROR_NOT_INITIALIZED;
	if (!device_count)
		return AUB_ERROR_NO_DEVICE_FOUND;

	list_for_each (pos, &device_list->list) {
		adev = list_entry(pos, struct aub_device, list);
		if ((struct aub_device *)dev == adev)
			return (int)adev->devnum;
	}
	return AUB_ERROR_NO_DEVICE_FOUND;
}

int AUB_CALL aub_open(aub_device_t *dev)
{
	struct aub_device *adev;
	struct list_head *pos;

	if (!usb_ctx)
		return AUB_ERROR_NOT_INITIALIZED;
	if (!device_list)
		return AUB_ERROR_NOT_INITIALIZED;
	if (!device_count)
		return AUB_ERROR_NO_DEVICE_FOUND;

	list_for_each (pos, &device_list->list) {
		adev = list_entry(pos, struct aub_device, list);
		if (!open_device(adev)) {
			*dev = (aub_device_t)adev;
			return AUB_SUCCESS;
		}
	}
	return AUB_ERROR_NO_DEVICE_FOUND;
}

int AUB_CALL aub_open_by_number(aub_device_t *dev, unsigned int dev_number)
{
	struct aub_device *adev;
	struct list_head *pos;

	if (!usb_ctx)
		return AUB_ERROR_NOT_INITIALIZED;
	if (!device_list)
		return AUB_ERROR_NOT_INITIALIZED;
	if (!device_count)
		return AUB_ERROR_NO_DEVICE_FOUND;

	list_for_each (pos, &device_list->list) {
		adev = list_entry(pos, struct aub_device, list);
		if (adev->devnum == dev_number) {
			if (!open_device(adev)) {
				*dev = (aub_device_t)adev;
				return AUB_SUCCESS;
			}
		}
	}
	return AUB_ERROR_NO_DEVICE_FOUND;
}

int AUB_CALL aub_open_by_serial(aub_device_t *dev, const char *serial)
{
	struct aub_device *adev;
	struct list_head *pos;

	if (!usb_ctx)
		return AUB_ERROR_NOT_INITIALIZED;
	if (!device_list)
		return AUB_ERROR_NOT_INITIALIZED;
	if (!device_count)
		return AUB_ERROR_NO_DEVICE_FOUND;

	list_for_each (pos, &device_list->list) {
		adev = list_entry(pos, struct aub_device, list);
		if (strcmp((const char *)adev->info.serial, serial) == 0) {
			if (!open_device(adev)) {
				*dev = (aub_device_t)adev;
				return AUB_SUCCESS;
			}
		}
	}
	return AUB_ERROR_NO_DEVICE_FOUND;
}

void AUB_CALL aub_close(aub_device_t dev)
{
	struct aub_device *adev = (struct aub_device *)dev;

	if (adev)
		close_device(adev);
}

int AUB_CALL aub_send(aub_device_t dev, const void *data, int length)
{
	const unsigned char *pdata = (const unsigned char *)data;
	struct aub_device *adev = (struct aub_device *)dev;
	int res, act_len, send_len, cur_len = 0;

	length *= adev->width_k[AUB_CHAN_OUT];
	if (length == 0 || length < 0)
		return 0;

	if (adev->cfg.mode == AUB_MODE_PACKET) {
		if (request_reg_write(adev, REG_TLR, length))
			return AUB_ERROR_IO;
	}

	do {
		send_len = (length > adev->wmaxpacketsize) ? adev->wmaxpacketsize : length;
		res = bulk_send(adev, pdata + cur_len, send_len, &act_len);
		act_len /= adev->width_k[AUB_CHAN_OUT];
		if (res < 0) {
			if ((res == LIBUSB_ERROR_PIPE) || (res == LIBUSB_ERROR_TIMEOUT)) {
				if (adev->cfg.mode == AUB_MODE_STREAM) {
					cur_len += act_len;
					break;
				}
			} else {
				return AUB_ERROR_IO;
			}
		}
		cur_len += act_len;
		length -= act_len;
	} while (length > 0);
	return cur_len;
}

int AUB_CALL aub_recv(aub_device_t dev, void *data, int length)
{
	unsigned char *pdata = (unsigned char *)data;
	struct aub_device *adev = (struct aub_device *)dev;
	uint16_t reg_data = 0;
	int res, act_len, cur_len;

	length *= adev->width_k[AUB_CHAN_IN];
	if (length == 0 || length < 0)
		return 0;

	if (adev->cfg.mode == AUB_MODE_PACKET) {
		if (request_reg_write(adev, REG_RSR, 0))
			return AUB_ERROR_IO;
	}
	cur_len = 0;
	do {
		res = bulk_recv(adev, pdata + cur_len, adev->wmaxpacketsize, &act_len);
		act_len /= adev->width_k[AUB_CHAN_IN];
		if (res < 0) {
			if ((res == LIBUSB_ERROR_PIPE) || (res == LIBUSB_ERROR_TIMEOUT)) {
				if (adev->cfg.mode == AUB_MODE_STREAM) {
					cur_len += act_len;
					break;
				} else {
					continue;
				}
			} else {
				return AUB_ERROR_IO;
			}
		}
		length -= act_len;
		cur_len += act_len;
		if (adev->cfg.mode == AUB_MODE_PACKET) {
			if (request_reg_read(adev, REG_RSR, &reg_data))
				return AUB_ERROR_IO;
			if (reg_data & REG_RSR_BIT_LST)
				return cur_len;
		}
	} while (length > 0);
	if (adev->cfg.mode == AUB_MODE_PACKET)
		return AUB_ERROR_OVERFLOW;

	return cur_len;
}

static int create_device_list(void)
{
	struct libusb_device_descriptor desc;
	libusb_device **dev_list;
	struct aub_device *adev;
	libusb_device *dev;
	ssize_t dev_count;

	device_count = 0;
	device_list = (struct aub_device *)malloc(sizeof(struct aub_device));
	if (!device_list)
		return AUB_ERROR_LOWLEVEL;
	device_list->dev = NULL;
	device_list->hdev = NULL;
	INIT_LIST_HEAD(&device_list->list);

	dev_count = libusb_get_device_list(usb_ctx, &dev_list);
	if (dev_count < 0)
		return AUB_ERROR_LOWLEVEL;

	for (int i = 0; i < dev_count; i++) {
		if ((dev = dev_list[i]) == NULL)
			break;
		if (libusb_get_device_descriptor(dev, &desc) < 0)
			continue;
		if ((desc.idVendor == VENDOR_ID) && (desc.idProduct == PRODUCT_ID)) {
			adev = (struct aub_device *)malloc(sizeof(struct aub_device));
			if (!adev) {
				libusb_free_device_list(dev_list, 1);
				return AUB_ERROR_LOWLEVEL;
			}
			adev->dev = dev;
			adev->hdev = NULL;
			adev->devnum = device_count++;
			adev->busnum = libusb_get_bus_number(dev);
			adev->devaddr = libusb_get_device_address(dev);
			open_device(adev);
			close_device(adev);
			list_add_tail(&adev->list, &device_list->list);
		}
	}
	libusb_free_device_list(dev_list, 0);
	return AUB_SUCCESS;
}

static void destroy_device_list(void)
{
	struct list_head *pos, *q;
	struct aub_device *adev;

	if (!device_list)
		return;
	list_for_each_safe(pos, q, &device_list->list) {
		adev = list_entry(pos, struct aub_device, list);
		list_del(pos);
		close_device(adev);
		free(adev);
	}
	device_count = 0;
	free(device_list);
}

static int open_device(struct aub_device *adev)
{
	if (adev->hdev)
		return AUB_ERROR_NOT_INITIALIZED;
	if (libusb_open(adev->dev, &adev->hdev)) {
		return AUB_ERROR_LOWLEVEL;
	} else {
		libusb_reset_device(adev->hdev);
		libusb_get_device_descriptor(adev->dev, &adev->desc);
		libusb_get_string_descriptor_ascii(adev->hdev, adev->desc.iManufacturer, adev->info.manufacturer, INFO_SIZE);
		libusb_get_string_descriptor_ascii(adev->hdev, adev->desc.iProduct, adev->info.product, INFO_SIZE);
		libusb_get_string_descriptor_ascii(adev->hdev, adev->desc.iSerialNumber, adev->info.serial, INFO_SIZE);
		libusb_claim_interface(adev->hdev, 0);
		if (request_cfg_get(adev)) {
			close_device(adev);
			return AUB_ERROR_IO;
		}
		for (int i = 0; i < 2; i++) {
			switch (adev->cfg.chan[i].width) {
			case DATA_WIDTH_NONE:
				adev->width_k[i] = 0;
				break;
			case DATA_WIDTH_8:
				adev->width_k[i] = 1;
				break;
			case DATA_WIDTH_16:
				adev->width_k[i] = 2;
				break;
			case DATA_WIDTH_32:
				adev->width_k[i] = 4;
				break;
			}
		}
		adev->wmaxpacketsize = adev->cfg.speed ? PACKETSIZE_HS : PACKETSIZE_FS;
	}
	return AUB_SUCCESS;
}

static void close_device(struct aub_device *adev)
{
	if (adev->hdev) {
		libusb_release_interface(adev->hdev, 0);
		libusb_close(adev->hdev);
		adev->hdev = NULL;
	}
}

static inline int bulk_send(struct aub_device *adev, const unsigned char *data, uint16_t length, int *act_len)
{
	return libusb_bulk_transfer(adev->hdev, BULK_ENDPOINT_OUT, (unsigned char *)data, length, act_len, TIMEOUT);
}

static inline int bulk_recv(struct aub_device *adev, unsigned char *data, uint16_t length, int *act_len)
{
	return libusb_bulk_transfer(adev->hdev, BULK_ENDPOINT_IN, data, length, act_len, TIMEOUT);
}

static inline int request_reg_read(struct aub_device *adev, uint16_t regaddr, uint16_t *regval)
{
	int res = libusb_control_transfer(adev->hdev, REQUEST_TYPE_IN, REQUEST_REG_OPER, regaddr, 0, (uint8_t *)regval, sizeof(uint16_t), TIMEOUT);
	if (res == sizeof(uint16_t))
		return AUB_SUCCESS;
	else
		return AUB_ERROR_IO;
}

static inline int request_reg_write(struct aub_device *adev, uint16_t regaddr, uint16_t regval)
{
	int res = libusb_control_transfer(adev->hdev, REQUEST_TYPE_OUT, REQUEST_REG_OPER, regaddr, 0, (uint8_t *)&regval, sizeof(uint16_t), TIMEOUT);
	if (res == sizeof(uint16_t))
		return AUB_SUCCESS;
	else
		return AUB_ERROR_IO;
}

static inline int request_cfg_get(struct aub_device *adev)
{
	int res = libusb_control_transfer(adev->hdev, REQUEST_TYPE_IN, REQUEST_CFG_GET, 0, 0, (uint8_t *)&adev->cfg, sizeof(struct aub_config), TIMEOUT);
	if (res == sizeof(struct aub_config))
		return AUB_SUCCESS;
	else
		return AUB_ERROR_IO;
}
