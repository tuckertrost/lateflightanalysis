# Late Flight Analysis
Analysis of data on late flights

```{python}
#| label: libraries
#| include: false
import pandas as pd
import numpy as np
import plotly.express as px
```

### Elevator pitch

_This project analyzes different aspects of flight delays and airports using the provided data. After thoroughly cleaning the data, we utilize various charts and tables to help us determine the best month to fly, the airport with the worst delays, and how weather impacts these delays._

```{python}
#| label: project-data
#| code-summary: Read and format project data
url = 'https://raw.githubusercontent.com/byuidatascience/data4missing/master/data-raw/flights_missing/flights_missing.json'
flights = pd.read_json(url)
```

### Data Cleaning

__Fix all of the varied missing data types in the data to be consistent (all missing values should be displayed as “NaN”).__

_Results: Before any analysis can be performed, the data must be cleaned. After an examination of the provided data, I noticed a few things. The column 'num of delays late aircraft' has a uses the placeholder -999 instead of NaN so this was changed. Additionally, the month column used the string 'n/a' so this was changed to NaN as well. Once the cleaning was complete, an example row of data in raw json format was produced._

```{python}
#| label: Q1
#| code-summary: Clean data

# Make a copy of the data for cleaning
flights_clean = flights.copy()

# Replace -999 with NaN
flights_clean['num_of_delays_late_aircraft'] = flights_clean.num_of_delays_late_aircraft.replace(-999,np.nan)

# Replace the string 'n/a' with NaN
flights_clean['month'] = flights_clean.month.replace('n/a',np.nan)

# Replace 1500+ with 1500
flights_clean['num_of_delays_carrier'] = flights_clean.num_of_delays_carrier.replace('1500+',1500)

# Print example record in raw json format
selected_row = flights_clean.iloc[0]
json_row = selected_row.to_json()
print(json_row)
```
### Insight 1: Worst Airport

__Which airport has the worst delays?__

_Insights: According to the data, it seems that `San Francisco International` has the worst delays of the included airports with flights being delayed `26.1%` of the time and an average of `1 hour` per delay. To determined this I created a summary table of each of the airports and determined the airport with the worst delays based on the computed delay percentage and average time of the delay._


```{python}
#| label: Q2
#| code-summary: Determine airport with worst delays

# Filter out needed columns
worst_airport = flights_clean.filter(['airport_code','airport_name','num_of_flights_total','num_of_delays_total','minutes_delayed_total'])

# Create delay percentage column
worst_airport['delay_percentage'] = round((worst_airport['num_of_delays_total'] / worst_airport['num_of_flights_total']) * 100,1)

# Create Average delay time column
worst_airport['avg_delay_time_in_hrs'] = round((worst_airport['minutes_delayed_total'] / worst_airport['num_of_delays_total']) / 60,2)

# Create summary table
worst_airport.groupby('airport_code').agg({'num_of_flights_total': np.sum,'num_of_delays_total': np.sum, 'minutes_delayed_total': np.sum,'delay_percentage': np.mean,'avg_delay_time_in_hrs': np.mean}).round(1).sort_values(['delay_percentage','avg_delay_time_in_hrs'], ascending = False).reset_index()


```


### Insight 2: Best Month

__What is the best month to fly if you want to avoid delays of any length?__

_To avoid delays of any length while traveling we'll look at the delay percentage for each month. This helps you choose the month that gives you the best chance of avoiding delays. The best month to go would be `September` with flights only being delayed `16.5%` of the time. This is compared to the worst month to fly, December, with flights being delayed 25.7% of the time._


```{python}
#| label: Q3
#| code-summary: Best Month to Avoid Delays

# Remove null values
df_month = flights_clean[flights_clean['month'].notnull()]

# Group needed columns by month
month_group = df_month.groupby('month', as_index=False, sort=False).agg({'num_of_flights_total': 'sum', 'num_of_delays_total': 'sum','minutes_delayed_total': 'sum'})

# Compute delay percentage
month_group['delay_percentage'] = round((month_group['num_of_delays_total'] / month_group['num_of_flights_total']) * 100,1)

# Compute average delay time
month_group['avg_delay_time_in_hrs'] = round((month_group['minutes_delayed_total'] / month_group['num_of_delays_total']) / 60,2)


```

```{python}
#| label: Q3-chart
#| code-summary: Delay percentages per month
#| fig-align: center

# Create plot
percent_fig = px.line(month_group, x='month',y='delay_percentage', title = 'Delay Percentages per Month')

# Annotate best month
percent_fig.add_annotation(x='September', y=16.5,
            text="16.5 percent chance of delay",
            showarrow=True,
            arrowhead=1)
percent_fig.show()

```


### Insight 3: Weather Delays

__What proportion of flights are delayed due to weather at each airport?__

_Weather accounts for a decent amount of flight delays at these airports. Based on the provided bar chart, we see that the airport with the highest proportion of flight delays due to weather is `San Franciso International`. This is followed closely by `Chicago O'Hare International`. On the flip side `Salt Lake City International` sees the smallest proportion of weather delays with about half as many as San Francisco._


```{python}
#| label: Q4+Q5
#| code-summary: Compute weather totals

weather = (flights_clean.assign(
            # Create severe column
            severe= flights_clean.num_of_delays_weather, 
            # Fill -999 with NaN
            nodla_nona = lambda x: (x.num_of_delays_late_aircraft.replace(-999,np.nan)),
            # 30% of late flights due to weather
            mild_late = lambda x: x.nodla_nona.fillna(x.nodla_nona.mean())*0.3,
            # From April to August, 40% of delayed flights in the NAS category are due to weather. The rest of the months, the proportion rises to 65%
            mild = np.where(
                flights_clean.month.isin(['April','May','June','July','August']),
                    flights_clean.num_of_delays_nas*0.4,
                    flights_clean.num_of_delays_nas*0.65),
            # Total weather delays
            weather = lambda x: x.severe + x.mild_late + x.mild,
            # Compute proportions
            proportion_weather_delay = lambda x: x.weather / x.num_of_delays_total,
            proportion_weather_total = lambda x: x.weather / x.num_of_flights_total))
# Filter Needed columns
weather_filter = weather.filter(['airport_code','month','year','severe','mild','mild_late','weather','proportion_weather_total','proportion_weather_delay','num_of_flights_total','num_of_delays_total'])

# Group by airport
weather_group = weather_filter.groupby('airport_code').agg({'proportion_weather_total': 'mean'})
weather_group = weather_group.reset_index()
weather_group.head(5)
```

```{python}
#| label: Q5-chart
#| code-summary: Weather delays by airport
#| fig-cap: "Proportion of Weather Delays by Airport"
#| fig-align: center

fig_weather = px.bar(weather_group, x='airport_code',y='proportion_weather_total', title = 'Proportion of Weather Delays by Airport')
fig_weather.show()

```


### Insight 4: Worst Delay

__Which delay is the worst delay?__

_To determine which delay is the worst we can focus on three types of delays: Weather, Carrier, and Security. From the provided bar chart, we see that based on proportion, `weather delays would be considered the worst delay` of the three. Weather delays are followed closely by carrier delays, however, it seems that security delays happen so infrequently that it is barely shown on the chart when compared to the other two._

```{python}
#| label: Stretch
#| code-summary: Clean data and pull proportions

delays = (weather
          .assign(
              # Replace '1500+' with 1500 integer
              num_of_delays_carrier = lambda x: (x.num_of_delays_carrier.replace('1500+',1500).astype(int)),
              # Compute additional proportions
              proportion_carrier_total=lambda x: x.num_of_delays_carrier / x.num_of_flights_total,
              proportion_security_total=lambda x: x.num_of_delays_security / x.num_of_flights_total
          )
          .filter(['airport_code', 'month', 'year', 'proportion_weather_total', 'proportion_carrier_total', 'proportion_security_total'])
)

# Create new dataframe from needed proportions
worst_delays = delays[['proportion_weather_total','proportion_carrier_total','proportion_security_total']].mean().reset_index()
worst_delays.columns = ['delay_type', 'mean_proportion']
worst_delays = pd.DataFrame(worst_delays)
worst_delays

```

```{python}
#| label: Stretch-chart
#| code-summary: Plot Proportions
#| fig-cap: "Worst Delay by Proportion"
#| fig-align: center

delay_fig = px.bar(worst_delays, x='delay_type',y='mean_proportion',title='Worst Delay by Proportion')
delay_fig.show()

```


