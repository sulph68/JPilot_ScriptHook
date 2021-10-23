#!/usr/bin/python3

import todoist
import emoji
import json
import re
import os
import csv
from unidecode import unidecode
from datetime import date

# Credentials files
cred_file = os.getenv('HOME') + "/.jpilot/credentials.json"

# Input csv file location
csv_file = os.getenv('HOME') + "/.jpilot/raw/todoist.jpilot"

# monthly recurring on same date: "[---99:99 sR@D.... OOOO@A@@@@]"
monthly_recurring = "[---99:99 sR@D.... OOOO@A@@@@]"

# make sure that strings are basic ascii
def ascii_str(s):
	try:
		s = emoji.demojize(s)
	except:
		s = str(s)
	s = unidecode(s)
	return str(s)

# change the date to jpilot date format
def palm_date(d):
	if d == "":
		return ""
	else:
		obj = date.fromisoformat(d)
		return str(obj.strftime("%Y/%m/%d"))

# add quotes for CSV
def qq(s):
	return str("\"" + s + "\"")

# map category from todoist to Palm
def map_category(c):
	if c == "Personal":
		return "Personal"
	elif c == "Business":
		return "Business"
	else:
		return "Unfiled"

# Authentification
with open(cred_file, "r") as file:
	credentials = json.load(file)
	todoist_cr = credentials['todoist']
	TOKEN = todoist_cr['TOKEN']

api = todoist.TodoistAPI(TOKEN)
api.sync()

projects = api.state['projects']
items = api.state['items']

# read the csv into a dict
with open(csv_file, mode='r') as csv_file:
	csv_reader = csv.DictReader(csv_file)
	for row in csv_reader:
		# get all fields for each row
		project_name = map_category(row['Category'])
		indefinite = row['Indefinite']
		due = row['Due Date']
		priority = row['Priority']
		is_completed = row['Completed']
		title = row['ToDo Text']
		description = row['Note']

		# format due date correctly if exist
		if (len(due) > 0):
			(year, month, day) = due.split("/",2)
			if len(month) < 2:
				month = "0" + str(month)
			if len(day) < 2:
				day = "0" + str(day)
			due = year + "/" + month + "/" + day

		# print("Processing Item: " + title)
		
		item_id = ""
		m = re.match(r'^.*\| ID: (\d+) \|', description)
		if m:
			item_id = m.group(1)
		# print("Got ID: " + item_id + "\n")
		if item_id != "":
			# should be an existing record. Update process
			print("Updating item ID: " + item_id)
			# check the due dates and format date if required
			if int(indefinite) == 1:
				due = None
			else:
				due = { "date":due.replace("/","-"),"timezone":None,"string":"","lang":"en","is_recurring":False }

			# get the item object and update it
			api.items.get_by_id(int(item_id)).update(content=title, description=description, due=due, priority=int(priority))	
			# check if completed
			if is_completed == "1":
				print("Existing item (" + item_id + ") completed!")
				api.items.get_by_id(int(item_id)).complete()
		else:
			# should be a new record. Create New
			# if item is already completed don't bother adding
			if is_completed == "1":
				print("New item completed! Skipping.")
			else:
				project_id = 0
				for p in projects:
					if p['name'] == project_name:
						project_id = p['id']
						break
				if int(indefinite) == 1:
					due = None
				else:
					due = { "date":due.replace("/","-"),"timezone":None,"string":"","lang":"en","is_recurring":False }
				# before adding a new item, make sure that an existing item title doesn't exist
				found = 0
				for item in items:
					if title == item['content']:
						# will add as new later store the id in found
						found = item['id']
						break
				if found == 0:
					print("Adding new item into category (" + str(project_id) + "): " + project_name)
					print("Title: " + title)
					print("Description: " + description)
					print("Due: " + str(due))
					item = api.items.add(content=title, description=description, project_id=project_id, due=due, priority=int(priority))
				else:
					# update the unsynced id and update it
					print("Updating existing unsynced matched title: " + str(title))
					api.items.get_by_id(int(found)).update(content=title, description=description, due=due, priority=int(priority))	
		# print("\n")

print("Commiting changes")
api.commit()
