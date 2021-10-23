#!/usr/bin/python3

import todoist
import emoji
import json
import re
import os
from unidecode import unidecode
from datetime import date

# Credentials files
cred_file = os.getenv('HOME') + "/.jpilot/credentials.json"

# Output csv file location
csv_file = os.getenv('HOME') + "/.jpilot/raw/todoist.csv"

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

# write to file
file_h = open(csv_file, "w")
# write initial header
csv_header = "CSV todo version 1.8.2: Category, Private, Indefinite, Due Date, Priority, Completed, ToDo Text, Note"
file_h.writelines(csv_header + "\n")

projects = api.state['projects']
items = api.state['items']

for p in projects:
	# make sure project isn't deleted
	if p['is_deleted'] == 0:
		for i in items:
			# make sure item has a proper ID
			if i['project_id'] == p['id'] and re.match(r'^\d+$', str(i['id'])):
				# skip item if deleted
				if i['is_deleted'] == 1:
					continue
				# category = name of project
				category = ascii_str(p['name'])
				# private defaults to "no"
				private = "0"
				# priority default 1
				priority = ascii_str(i['priority'])
				# date completed default 0
				completed = "0"
				date_completed = "0"
				if i['date_completed'] != None:
					date_completed = ascii_str(i['date_completed'])
					completed = "1"
				# todo title					
				title = ascii_str(i['content'])
				# todo description
				description = ascii_str(i['description']).replace("\n"," ")

				# indefinite = no due date
				indefinite = "1"
				due = ""
				is_recurring = "0"
				note_prefix = ""
				if i['due'] != None:
					due = ascii_str(i['due']['date'])
					indefinite = "0"
					if i['due']['is_recurring'] == True:
						is_recurring = "1"
						category = "Recurring"
						if re.match(r'every\s+\d+.+$', i['due']['string']):
							note_prefix = monthly_recurring

				# extra info for notes
				itemid = ascii_str(i['id'])
				date_added = ascii_str(i['date_added'])
				if re.match(r'^.*\| ID: \d+ \|', description):
					# make sure that notes wasn't pre-composed from Palm
					notes = description
					notes.replace("Date Completed: 0", "Date Completed: " + date_completed)
				else:
					# Format the note for Palm
					notes = note_prefix + "| "
					notes += "ID: " + itemid + " | " 
					notes += "Category: " + category + " | " 
					notes += "Date Added: " + date_added + " | " 
					notes += "Date Completed: " + date_completed + " | "
					notes += "Description: " + description + " |"

				# compile the data for CSV
				data = ""
				data += qq(map_category(category)) + ","
				data += qq(private) + ","
				data += qq(indefinite) + ","
				data += qq(palm_date(due)) + ","
				data += qq(priority) + ","
				data += qq(completed) + ","
				data += qq(title) + ","
				data += qq(notes) 
		
				print(data)
				file_h.writelines(data + "\n")

# close file
file_h.close()
