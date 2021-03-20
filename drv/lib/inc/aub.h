/**
 * @file aub.h
 * @brief AXIS USB Bridge Header
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

#ifndef AUB_H_
#define AUB_H_

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _WIN32
#include <windows.h>
#ifdef AUB_EXPORT
#define AUB_API __declspec(dllexport)
#elif defined(AUB_STATIC)
#define AUB_API
#else
#define AUB_API __declspec(dllimport)
#endif
#define AUB_CALL WINAPI
#else
#define AUB_API
#define AUB_CALL
#endif

typedef void* aub_device_t;

enum AUB_CHAN {
	AUB_CHAN_IN = 0,
	AUB_CHAN_OUT = 1
};

enum AUB_ERROR {
	AUB_SUCCESS = 0,
	AUB_ERROR_LOWLEVEL = -1,
	AUB_ERROR_NOT_INITIALIZED = -2,
	AUB_ERROR_NO_DEVICE_FOUND = -3,
	AUB_ERROR_NOT_READY = -4,
	AUB_ERROR_OVERFLOW = -5,
	AUB_ERROR_IO = -6,
};

enum AUB_STATE {
	AUB_DISABLED = 0,
	AUB_ENABLED = 1
};

enum AUB_ENDIANESS {
	AUB_LITTLE_ENDIAN = 0,
	AUB_BIG_ENDIAN = 1
};

enum AUB_MODE {
	AUB_MODE_STREAM = 0,
	AUB_MODE_PACKET = 1
};

struct aub_device_info {
	unsigned int devnum;
	unsigned char busnum;
	unsigned char devaddr;
	struct {
		const char *manufacturer;
		const char *product;
		const char *serial;
	} str;
	struct {
		struct {
			unsigned char enabled;
			unsigned int width;
			unsigned char endianess;
			unsigned char fifo_enabled;
			unsigned char fifo_mode;
			unsigned int fifo_depth;
		} chan[2];
		unsigned char speed;
		unsigned char mode;
	} config;
};

/**
 * @brief Open library and create device list
 * @return error_code (see <enum AUB_ERROR>)
 */
int AUB_CALL AUB_API aub_init(void);

/**
 * @brief Close library and free device list
 * @return error_code (see <enum AUB_ERROR>)
 */
void AUB_CALL AUB_API aub_deinit(void);

/**
 * @brief Get AUB device count
 * @return error_code (see <enum AUB_ERROR>) or device count
 */
int AUB_CALL AUB_API aub_get_device_count(void);

/**
 * @brief Get AUB device information
 * @param dev_number AUB device number
 * @param dev_info Pointer to info structure
 * @return error_code (see <enum AUB_ERROR>)
 */
int AUB_CALL AUB_API aub_get_device_info(unsigned int dev_number, struct aub_device_info *dev_info);

/**
 * @brief Get AUB device number
 * @param dev AUB device
 * @return error_code (see <enum AUB_ERROR>) or device number
 */
int AUB_CALL AUB_API aub_get_device_number(aub_device_t dev);

/**
 *	@brief Open AUB device with lowest accessible number
 *	@param dev Pointer to AUB device
 *	@return error_code (see <enum AUB_ERROR>)
 */
int AUB_CALL AUB_API aub_open(aub_device_t *dev);

/**
 * @brief Open AUB device by device number
 * @param dev Pointer to AUB device
 * @param dev_number Device number
 * @return error_code (see <enum AUB_ERROR>)
 */
int AUB_CALL AUB_API aub_open_by_number(aub_device_t *dev, unsigned int dev_number);

/**
 * @brief Open AUB device by serial number
 * @param dev Pointer to AUB device
 * @param serial Serial number
 * @return error_code (see <enum AUB_ERROR>)
 */
int AUB_CALL AUB_API aub_open_by_serial(aub_device_t *dev, const char *serial);

/**
 * @brief Close AUB device
 * @param dev AUB device
 * @return error_code (see <enum AUB_ERROR>)
 */
void AUB_CALL AUB_API aub_close(aub_device_t dev);

/**
 * @brief Send data
 * @param dev AUB device
 * @param data Pointer to data array
 * @param length Array length
 * @return error_code (see <enum AUB_ERROR>) or number of elements actual sent
 */
int AUB_CALL AUB_API aub_send(aub_device_t dev, const void *data, int length);

/**
 * @brief Receive data
 * @param dev AUB device
 * @param data Pointer to data array
 * @param length Array length
 * @return error_code (see <enum AUB_ERROR>) or number of elements actual received
 */
int AUB_CALL AUB_API aub_recv(aub_device_t dev, void *data, int length);


#ifdef __cplusplus
}
#endif

#endif /* AUB_H_ */
