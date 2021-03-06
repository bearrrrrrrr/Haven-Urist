/datum/ui_module/program/email_administration/
	name = "Email Administration"
	ui_interface_name = "program/EmailAdministrationProgram"

	var/datum/computer_file/data/email_account/current_account = null
	var/datum/computer_file/data/email_message/current_message = null
	var/error = ""

/datum/ui_module/program/email_administration/ui_data(mob/user)
	var/list/data = host.initial_data()

	if(error)
		data["error"] = error
	else if(istype(current_message))
		data["msg_title"] = current_message.title
		data["msg_body"] = pencode2html(current_message.stored_data)
		data["msg_timestamp"] = current_message.timestamp
		data["msg_source"] = current_message.source
	else if(istype(current_account))
		data["current_account"] = current_account.login
		data["cur_suspended"] = current_account.suspended
		var/list/all_messages = list()
		for(var/datum/computer_file/data/email_message/message in (current_account.inbox | current_account.spam | current_account.deleted))
			all_messages.Add(list(list(
				"title" = message.title,
				"source" = message.source,
				"timestamp" = message.timestamp,
				"uid" = message.uid
			)))
		data["messages"] = all_messages
		data["messagecount"] = all_messages.len
	else
		var/list/all_accounts = list()
		for(var/datum/computer_file/data/email_account/account in ntnet_global.email_accounts)
			if(!account.can_login)
				continue
			all_accounts.Add(list(list(
				"login" = account.login,
				"uid" = account.uid
			)))
		data["accounts"] = all_accounts
		data["accountcount"] = all_accounts.len

	return data

/datum/ui_module/program/email_administration/Topic(href, href_list)
	if(..())
		return 1

	var/mob/user = usr
	if(!istype(user))
		return 1

	// High security - can only be operated when the user has an ID with access on them.
	var/obj/item/weapon/card/id/I = user.GetIdCard()
	if(!istype(I) || !(access_network in I.access))
		return 1

	if(href_list["back"])
		if(error)
			error = ""
		else if(current_message)
			current_message = null
		else
			current_account = null
		return 1

	if(href_list["ban"])
		if(!current_account)
			return 1

		current_account.suspended = !current_account.suspended
		ntnet_global.add_log_with_ids_check("EMAIL LOG: SA-EDIT Account [current_account.login] has been [current_account.suspended ? "" : "un" ]suspended by SA [I.registered_name] ([I.assignment]).")
		error = "Account [current_account.login] has been [current_account.suspended ? "" : "un" ]suspended."
		return 1

	if(href_list["changepass"])
		if(!current_account)
			return 1

		var/newpass = sanitize(input(user,"Enter new password for account [current_account.login]", "Password"), 100)
		if(!newpass)
			return 1
		current_account.password = newpass
		ntnet_global.add_log_with_ids_check("EMAIL LOG: SA-EDIT Password for account [current_account.login] has been changed by SA [I.registered_name] ([I.assignment]).")
		return 1

	if(href_list["viewmail"])
		if(!current_account)
			return 1

		for(var/datum/computer_file/data/email_message/received_message in (current_account.inbox | current_account.spam | current_account.deleted))
			if(received_message.uid == text2num(href_list["viewmail"]))
				current_message = received_message
				break
		return 1

	if(href_list["viewaccount"])
		for(var/datum/computer_file/data/email_account/email_account in ntnet_global.email_accounts)
			if(email_account.uid == text2num(href_list["viewaccount"]))
				current_account = email_account
				break
		return 1

	if(href_list["newaccount"])
		var/newdomain = sanitize(input(user,"Pick domain:", "Domain name") as null|anything in GLOB.using_map.usable_email_tlds)
		if(!newdomain)
			return 1
		var/newlogin = sanitize(input(user,"Pick account name (@[newdomain]):", "Account name"), 100)
		if(!newlogin)
			return 1

		var/complete_login = "[newlogin]@[newdomain]"
		if(ntnet_global.find_email_by_name(complete_login))
			error = "Error creating account: An account with same address already exists."
			return 1

		var/datum/computer_file/data/email_account/new_account = new/datum/computer_file/data/email_account()
		new_account.login = complete_login
		new_account.password = GenerateKey()
		error = "Email [new_account.login] has been created, with generated password [new_account.password]"
		return 1
