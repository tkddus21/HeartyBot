import time

def longtime_job():
    print("job start")
    time.sleep(1)
    return 'done'

list_job = iter([longtime_job() for i in range(5)])
print(next(list_job))



list_job2 = (longtime_job() for i in range(5))
print(next(list_job2))