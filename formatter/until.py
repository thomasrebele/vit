from formatter import DateTime

class Until(DateTime):
    def get_until_state(self, until, task):
        return self.defaults.get_until_state(until, task)

    def colorize(self, until, task):
        return self.colorizer.until(self.get_until_state(until, task))
