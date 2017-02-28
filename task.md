The task:
1) Download watir-webdriver gem and write a script that visits google.com
2) Write a script that signs into <some_bank> interface. The script should ask the user to input the <credentials> using the gets method.
3) Write a script that navigates through the <some_bank> page and prints an array of objects in the following way:
```
account_name
currency_code
balance
nature [card, account]
```
4) Extend your script to store the list of accounts in JSON format. Example output:
```json
  {"accounts":
    [
      {
        "name": "account1",
        "balance": 300.22,
        "currency": "MDL",
        "nature": "checking"
      }
    ]
  }
``` 
5) Create a Transaction class that has the following fields:
date
description
amount
6) Extend your script to output the list of transactions for the last two months. Use the date picker on <some_bank> website
7) Extend your script in such a way that the stored JSON account will contain a list of Transactions. Example of output:
```json
  {"accounts":
    [
      {
        "name": "account1",
        "balance": 300.22,
        "currency": "MDL",
        "description": "My checking account",
        "transactions": [
          {
             "date": "2015-01-15T08:18:26Z",
             "description": "bought food",
             "amount": 20.31
          }
        ]
      }
    ]
  }
```
## BEFORE YOU BEGIN:
- Установка Ubuntu
- Установка TrueCrypt 7.1a(для Linux, для macOS можно использовать Disk Utility)
- Установка ZSH(опционально, но желательно)
- Установка RVM и Ruby
- Установка Sublime
- tryruby.org - пройти
- http://ruby.bastardsbook.com/chapters/numbers/ - читать
- http://ruby.bastardsbook.com/chapters/strings/ - читать
- http://ruby.bastardsbook.com/chapters/variables/ - читать
- http://ruby.bastardsbook.com/chapters/methods/ - читать
- Установить Watir-webdriver



> Copied from mail