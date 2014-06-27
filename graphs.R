library(RODBC)
library(reshape2)
library(ggplot2)
library(scales)
library(plyr)  # for join()

conn <- odbcConnect("parking")

boroughs <- c("Bronx","Brooklyn","Manhattan","Queens","Staten","New York")



data <- sqlQuery(conn,
		'SELECT regulation_id,
		"Day of week" * 48 + "Half hour" - 48 AS time,
		sum("Parking spots") AS spots,
		1 * max("Metered parking") +
		2 * max("Street cleaning") +
		3 * max("No parking") +
		4 * max("Free parking") AS status
		FROM parking_fact
		INNER JOIN regulation_time_dimension USING (regulation_id)
		WHERE "Day of week" IN (1,2)
		AND regulation_id IN (
			SELECT regulation_id
			FROM parking_fact
			INNER JOIN regulation_dimension USING (regulation_id)
			WHERE "Hours no parking" != 168
				AND "Hours no standing" != 168
				AND "Hours bus stop" != 168
			GROUP BY regulation_id
			ORDER BY sum("Parking spots") DESC
			LIMIT 200
			)
		GROUP BY regulation_id, time
		ORDER BY spots DESC, regulation_id, time')
z <- unique(subset(data, select=c(spots,regulation_id)))
z$cspots <- cumsum(z$spots)
datam <- join(data, z, type="left")
datam$x <- datam$cspots - datam$spots/2
ggplot(datam, aes(x=x, y=time+0.5, fill=factor(status), width=spots)) +
	geom_tile(alpha=.6) +
	scale_y_continuous(breaks=seq(0,48*2,24),
		labels=c("","Mon noon","","Tues noon","")) +
	scale_fill_discrete(labels=c("metered","cleaning","no parking","free")) +
	theme(legend.position="bottom") +
	labs(title=sprintf("Available parking spaces in New York, Monday to Tuesday"),
			y="Time of week",
			x="Estimated number of car spaces") +
	guides(fill = guide_legend(title=NULL))
ggsave(filename="Tile.png", width=8, height=8, dpi=100)



for (borough in boroughs) {

	if (borough == "New York") {
		where <- ""
		step <- 100000
	} else {
		where <- sprintf('WHERE "Borough" = \'%s\'', borough)
		step <- 20000
	}

	data <- sqlQuery(conn,
			sprintf('SELECT (("Day of week" + 6) %% 7) * 48 + "Half hour" AS time,
				sum("Parking spots" * "Metered parking") AS metered,
				sum("Parking spots" * "Street cleaning") AS cleaning,
				sum("Parking spots" * "No parking") AS no_parking,
				sum("Parking spots" * "Free parking") AS free
			FROM parking_fact 
			INNER JOIN block_dimension USING (block_id) 
			INNER JOIN regulation_dimension USING (regulation_id)
			INNER JOIN regulation_time_dimension USING (regulation_id)
			%s
			GROUP BY time
			ORDER BY time',
			where))



	datal <- melt(data, id.vars="time", variable.name="type", value.name="spots")
	datak <- rbind(datal, transform(datal, time=time+0.999))

	ggplot(datak, aes(x=time, y=spots, fill=type)) +
		geom_area(alpha=.6) +
		geom_line(position="stack", size=.1) +
		scale_x_continuous(breaks=seq(0,48*7,48),
			labels=c("Mon","Tues","Weds","Thu","Fri","Sat","Sun","")) +
		scale_y_continuous(breaks=seq(0,2000000,by=step), labels=comma) +
		theme(legend.position="bottom",
			axis.text.x = element_text(hjust=0)) +
		labs(title=sprintf("Parking spaces in %s", borough),
			x="Time of week",
			y="Estimated number of car spaces")
	ggsave(filename=sprintf("%s_stacked.png", borough), width=8, height=8, dpi=100)

	ggplot(datak, aes(x=time, y=spots, fill=type)) +
		facet_grid(type ~ ., scales="free", space="free") +
		geom_area(alpha=.6, size=.2) +
		geom_line(size=.1) +
		scale_x_continuous(breaks=seq(0,48*7,48),
			labels=c("Mon","Tues","Weds","Thu","Fri","Sat","Sun","")) +
		scale_y_continuous(breaks=seq(0,2000000,by=step), labels=comma) +
		theme(legend.position="none",
			axis.text.x = element_text(hjust=0)) +
		labs(title=sprintf("Parking spaces in %s", borough),
			x="Time of week",
			y="Estimated number of car spaces")
	ggsave(filename=sprintf("%s_grid.png", borough), width=8, height=8, dpi=100)

	ggplot(datak, aes(x=time, y=spots, fill=type)) +
		facet_grid(type ~ ., scales="free", space="free") +
		geom_area(alpha=.6, size=.2) +
		geom_line(size=.1) +
		scale_x_continuous(limits=c(0,48), breaks=seq(0,48,4),
			labels=seq(0,24,2)) +
		scale_y_continuous(breaks=seq(0,2000000,by=step), labels=comma) +
		theme(legend.position="none") +
		labs(title=sprintf("Parking spaces in %s on Monday", borough),
			x="Time on Monday",
			y="Estimated number of car spaces")
	ggsave(filename=sprintf("%s_monday_grid.png", borough), width=8, height=8, dpi=100)

}

