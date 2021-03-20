/**
 * @file list.h
 * @brief Modified list from Linux Kernel
 * @author mcjtag (https://github.com/mcjtag)
 * @date 20.03.2021
 * @copyright MIT License
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

#ifndef LIST_H
#define LIST_H

#define LIST_HEAD_INIT(name) { &(name), &(name) }
#define LIST_HEAD(name) struct list_head name = LIST_HEAD_INIT(name)
#define INIT_LIST_HEAD(ptr) do { (ptr)->next = (ptr); (ptr)->prev = (ptr); } while (0)

struct list_head {
	struct list_head *next, *prev;
};

/**
 * @brief Insert a new entry between two known consecutive entries
 * @param new New entry
 * @param prev Previous entry
 * @param next Next entry
 * @return void
 */
static inline void __list_add(struct list_head *new, struct list_head *prev, struct list_head *next)
{
	next->prev = new;
	new->next = next;
	new->prev = prev;
	prev->next = new;
}

/**
 * @brief Add a new entry (inserts a new entry after the specified head)
 * @param new New entry to be added
 * @param head List head to add it after
 * @return void
 */
static inline void list_add(struct list_head *new, struct list_head *head)
{
	__list_add(new, head, head->next);
}

/**
 * @brief Add a new entry (inserts a new entry before the specified head)
 * @param new New entry to be added
 * @param head List head to add it before
 * @return void
 */
static inline void list_add_tail(struct list_head *new, struct list_head *head)
{
	__list_add(new, head->prev, head);
}

/**
 * @brief Delete a list entry by making the prev/next entries point to each other
 * @param prev Previous entry
 * @param next Next entry
 * @return void
 */
static inline void __list_del(struct list_head *prev, struct list_head *next)
{
	next->prev = prev;
	prev->next = next;
}

/**
 * @brief Delete entry from list
 * @param entry The element to be deleted from the list
 * @return void
 */
static inline void list_del(struct list_head *entry)
{
	__list_del(entry->prev, entry->next);
	entry->next = (void *) 0;
	entry->prev = (void *) 0;
}

/**
 * @brief Delete entry from list and reinitialize it
 * @param entry The element to be deleted from the list
 * @return void
 */
static inline void list_del_init(struct list_head *entry)
{
	__list_del(entry->prev, entry->next);
	INIT_LIST_HEAD(entry); 
}

/**
 * @brief Delete from one list and add as another's head
 * @param list The entry to move
 * @param head The head that will precede our entry
 * @return void
 */
static inline void list_move(struct list_head *list, struct list_head *head)
{
	__list_del(list->prev, list->next);
	list_add(list, head);
}

/**
 * @brief Delete from one list and add as another's tail
 * @param list The entry to move
 * @param head The head that will follow our entry
 * @return void
 */
static inline void list_move_tail(struct list_head *list, struct list_head *head)
{
	__list_del(list->prev, list->next);
	list_add_tail(list, head);
}

/**
 * @brief Tests whether a list is empty
 * @param head The list to test.
 * @return 1 if empty
 */
static inline int list_empty(struct list_head *head)
{
	return head->next == head;
}

/**
 * @brief Splice two lists
 * @param list New list
 * @param head Head
 * @return void
 */
static inline void __list_splice(struct list_head *list, struct list_head *head)
{
	struct list_head *first = list->next;
	struct list_head *last = list->prev;
	struct list_head *at = head->next;

	first->prev = head;
	head->next = first;

	last->next = at;
	at->prev = last;
}

/**
 * @brief Join two lists
 * @param list The new list to add
 * @param head The place to add it in the first list
 * @return void
 */
static inline void list_splice(struct list_head *list, struct list_head *head)
{
	if (!list_empty(list))
		__list_splice(list, head);
}

/**
 * @brief Join two lists and reinitialize the emptied list
 * @param list The new list to add
 * @param head The place to add it in the first list
 * @return void
 */
static inline void list_splice_init(struct list_head *list, struct list_head *head)
{
	if (!list_empty(list)) {
		__list_splice(list, head);
		INIT_LIST_HEAD(list);
	}
}

/**
 * @brief Get the struct for this entry
 * @param ptr The &struct list_head pointer
 * @param type The type of the struct this is embedded in
 * @param member The name of the list_struct within the struct
 * @return pointer to the struct
 */
#define list_entry(ptr, type, member) \
	((type *)((uintptr_t)(ptr)-(uintptr_t)(&((type *)0)->member)))

/**
 * @brief Iterate over a list
 * @param pos The &struct list_head to use as a loop counter
 * @param head The head for your list
 */
#define list_for_each(pos, head) \
	for (pos = (head)->next; pos != (head); pos = pos->next)

/**
 * @brief Iterate over a list backwards
 * @param pos The &struct list_head to use as a loop counter
 * @param head The head for your list
 */
#define list_for_each_prev(pos, head) \
	for (pos = (head)->prev; pos != (head); pos = pos->prev)
        	
/**
 * @brief Iterate over a list safe against removal of list entry
 * @param pos The &struct list_head to use as a loop counter
 * @param n Another &struct list_head to use as temporary storage
 * @param head The head for your list
 */
#define list_for_each_safe(pos, n, head) \
	for (pos = (head)->next, n = pos->next; pos != (head); pos = n, n = pos->next)

/**
 * @brief Iterate over list of given type
 * @param pos The type * to use as a loop counter
 * @param head The head for your list
 * @param member The name of the list_struct within the struct
 */
#define list_for_each_entry(pos, head, member) \
	for (pos = list_entry((head)->next, typeof(*pos), member); \
	&pos->member != (head); \
	pos = list_entry(pos->member.next, typeof(*pos), member))

/**
 * @brief Iterate over list of given type safe against removal of list entry
 * @param pos The type * to use as a loop counter
 * @param n Another type * to use as temporary storage
 * @param head The head for your list
 * @param member The name of the list_struct within the struct
 */
#define list_for_each_entry_safe(pos, n, head, member) \
	for (pos = list_entry((head)->next, typeof(*pos), member), n = list_entry(pos->member.next, typeof(*pos), member);	\
	&pos->member != (head); \
	pos = n, n = list_entry(n->member.next, typeof(*n), member))

#endif
