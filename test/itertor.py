class MyIterto:
    def __init__(self, data):
        self.data = data
        self.position = 0

    def __iter__(self):
        return self
    
    def __next__(self):
        if self.position >= len(self.data):
            raise StopIteration
        result = self.data[self.position]
        self.position += 1
        return result
    

if __name__ == "__main__":
    i = MyIterto([1,2,3])
    print(type(i))
    for item in i:
        print(item)