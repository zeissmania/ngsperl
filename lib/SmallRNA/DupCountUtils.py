import operator
from QueryItem import QueryItem

def readDupCountQueries(fileName, minCount):
  result = []
  with open(fileName, "r") as sr:
    sr.readline()
    for line in sr:
      parts = line.rstrip().split('\t')
      query_name = parts[0]
      query_count = int(parts[1])
      query_sequence = parts[2]
      if query_count >= minCount:
        result.append(QueryItem(query_sequence, query_name, query_count))
  result.sort(key=operator.attrgetter('QueryCount'), reverse=True)
  return(result)
  