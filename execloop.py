import concurrent.futures
import threading
import subprocess
import time
import os
import signal
import logging


def preexec_setpgid():
    os.setpgid(0, 0)
    signal.signal(signal.SIGTTOU, signal.SIG_IGN)


    
class ExpRunner:
    def __init__(self, tasks, essential_task_ids, parallelism, interval=1):
        self.tasks = tasks
        self.parallelism = parallelism
        self.interval = interval

        self.task_finished = set()
        self.task_running = set()
        self.task_running_lock = threading.Lock()

        self.essential_tasks = essential_task_ids

        # self.task_pids = [-1] * len(tasks)
        self.task_proc = [None] * len(tasks)

        self.log = logging.getLogger("Runner")

        # self.running_procs = []

        # self.subproc_pids 
        # self.callback = callback
        # self.interval = interval
        # self.pids = set()
        # self.procs = []
        self.executor = concurrent.futures.ThreadPoolExecutor(max_workers=parallelism)
        self.futures = []



    def run(self):
        
        # push tasks
        for task_id, task in enumerate(self.tasks):
            future = self.executor.submit(self.run_task, task_id, task)
            self.futures.append(future)


        # while not all(f.done() for f in concurrent.futures.as_completed(futures)):
        #     time.sleep(self.interval)
        #     self.callback()
        
        while True:
            time.sleep(self.interval)

            # is all essential task finished?
            if all(map(lambda x: x in self.task_finished, self.essential_tasks)):
                self.log.info("All tasks completed. Killing unfinished tasks")
                self.kill_all()
                return

            tasks_finished_in_this_query = []
            self.task_running_lock.acquire()
            for task_id in self.task_running:
                p = self.task_proc[task_id]

                if p.poll() is not None:
                    # complete
                    tasks_finished_in_this_query.append(task_id)
                    self.log.info(f"Task {task_id} (pid {p.pid}) has completed.")

                    returncode = p.returncode
                    if returncode != 0:
                        self.log.error(f"Task {task_id} (pid {p.pid}) returned error (returncode = {returncode}, cmdline = {self.tasks[task_id]})")
                        self.kill_all()
                        exit(-1)
            for task_id in tasks_finished_in_this_query:
                self.task_finished.add(task_id)
                self.task_running.remove(task_id)
            
            self.task_running_lock.release()




    def run_task(self, task_id, task):
        # print(task)
        self.task_running_lock.acquire()
        self.log.debug(f"Start task {task_id}")
        p = subprocess.Popen(task, shell=True, stdin=subprocess.DEVNULL,
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             preexec_fn=preexec_setpgid)
        self.task_proc[task_id] = p
        self.task_running.add(task_id)
        self.task_running_lock.release()

        p.wait()

    def kill_all(self):
        # Cancel all pending tasks in the executor
        for f in self.futures:
            f.cancel()

        # Kill all simulators (process group): SIGTERM first, then SIGKILL so they actually exit
        time.sleep(0.2)
        self.task_running_lock.acquire()
        for task_id in list(self.task_running):
            p = self.task_proc[task_id]
            if p is None:
                continue
            try:
                os.killpg(p.pid, signal.SIGTERM)
            except (ProcessLookupError, PermissionError) as e:
                pass
            except Exception as e:
                self.log.debug("killpg SIGTERM: %s", e)
        self.task_running_lock.release()

        time.sleep(0.5)
        self.task_running_lock.acquire()
        for task_id in list(self.task_running):
            p = self.task_proc[task_id]
            if p is None:
                continue
            try:
                if p.poll() is None:
                    os.killpg(p.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            except Exception as e:
                self.log.debug("killpg SIGKILL: %s", e)
        self.task_running_lock.release()

        # Shutdown executor without waiting forever for workers stuck in wait()
        self.executor.shutdown(wait=False, cancel_futures=True)





if __name__ == "__main__":
    loggerList = [
        "Runner",
        "Tasks"
    ]
    fmtStr = "\u001b[31m[%(asctime)s]\u001b[33m[%(name)s]\u001b[35m[%(levelname)s]\u001b[34m: \u001b[0m%(message)s"


    def logSetup():
        for eachLoggerName in loggerList:
            formatter = logging.Formatter(fmtStr)
            handler = logging.StreamHandler()
            handler.setFormatter(formatter)

            logger = logging.getLogger(eachLoggerName)
            logger.addHandler(handler)

            logger.setLevel(logging.INFO)
    logSetup()

    tasks_list = [f"sleep {x}" for x in range(1, 10)]

    task_manager = ExpRunner(tasks_list, [0,1,2,4], 2)

    try:
        task_manager.run()
    except KeyboardInterrupt:
        print("KeyboardInterrupt: Killing all tasks")
        task_manager.kill_all()

