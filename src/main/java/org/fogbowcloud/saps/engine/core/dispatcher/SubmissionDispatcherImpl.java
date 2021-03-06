package org.fogbowcloud.saps.engine.core.dispatcher;

import java.sql.SQLException;
import java.sql.Timestamp;
import java.text.DateFormat;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.List;
import java.util.Locale;
import java.util.Properties;
import java.util.Set;
import java.util.UUID;

import org.apache.log4j.Logger;
import org.fogbowcloud.saps.engine.core.database.JDBCImageDataStore;
import org.fogbowcloud.saps.engine.core.model.ImageTask;
import org.fogbowcloud.saps.engine.core.model.ImageTaskState;
import org.fogbowcloud.saps.engine.core.model.SapsUser;																																		
import org.fogbowcloud.saps.engine.core.repository.USGSNasaRepository;
import org.fogbowcloud.saps.engine.core.util.DatasetUtil;
import org.fogbowcloud.saps.notifier.Ward;

public class SubmissionDispatcherImpl implements SubmissionDispatcher {
    public static final int DEFAULT_PRIORITY = 0;
    private final JDBCImageDataStore imageStore;
    private Properties properties;
    private USGSNasaRepository repository;

    private static final Logger LOGGER = Logger.getLogger(SubmissionDispatcherImpl.class);

    public SubmissionDispatcherImpl(JDBCImageDataStore imageStore, USGSNasaRepository repository) {
        this.imageStore = imageStore;
        this.repository = repository;
    }

    public SubmissionDispatcherImpl(Properties properties) throws SQLException {
        this.properties = properties;
        this.imageStore = new JDBCImageDataStore(properties);
        this.repository = new USGSNasaRepository(properties);
    }

    @Override
    public void addUserInDB(String userEmail, String userName, String userPass, boolean userState,
                            boolean userNotify, boolean adminRole) throws SQLException {
        try {
            imageStore.addUser(userEmail, userName, userPass, userState, userNotify, adminRole);
        } catch (SQLException e) {
            LOGGER.error("Error while adding user " + userEmail + " in Catalogue", e);
            throw new SQLException(e);
        }
    }

    @Override
    public void updateUserState(String userEmail, boolean userState) throws SQLException {
        try {
            imageStore.updateUserState(userEmail, userState);
        } catch (SQLException e) {
            LOGGER.error("Error while adding user " + userEmail + " in Catalogue", e);
            throw new SQLException(e);
        }
    }

    @Override
    public SapsUser getUser(String userEmail) {
        try {
            return imageStore.getUser(userEmail);
        } catch (SQLException e) {
            LOGGER.error("Error while trying to get Sebal User with email: " + userEmail + ".", e);
        }
        return null;
    }

    @Override
    public void addTaskNotificationIntoDB(String submissionId, String taskId, String userEmail)
            throws SQLException {
        try {
            imageStore.addUserNotification(submissionId, taskId, userEmail);
        } catch (SQLException e) {
            LOGGER.error("Error while adding task " + taskId + " notification for user " + userEmail
                    + " in Catalogue", e);
        }
    }

    @Override
    public void removeUserNotification(String submissionId, String taskId, String userEmail)
            throws SQLException {
        try {
            imageStore.removeNotification(submissionId, taskId, userEmail);
        } catch (SQLException e) {
            LOGGER.error("Error while removing task " + taskId + " notification for user "
                    + userEmail + " from Catalogue", e);
        }
    }

    @Override
    public boolean isUserNotifiable(String userEmail) throws SQLException {
        try {
            return imageStore.isUserNotifiable(userEmail);
        } catch (SQLException e) {
            LOGGER.error("Error while verifying user notify", e);
        }

        return false;
    }

    @Override
    public void setTasksToPurge(String day, boolean force) throws SQLException, ParseException {
        List<ImageTask> tasksToPurge = force ? imageStore.getAllTasks()
                : imageStore.getIn(ImageTaskState.ARCHIVED);

        for (ImageTask imageTask : tasksToPurge) {
            long date = 0;
            try {
                date = parseStringToDate(day).getTime();
            } catch (ParseException e) {
                LOGGER.error("Error while parsing string to date", e);
            }
            if (isBeforeDay(date, imageTask.getUpdateTime())) {
                imageTask.setStatus(ImageTask.PURGED);

                imageStore.updateImageTask(imageTask);
                imageTask.setUpdateTime(imageStore.getTask(imageTask.getTaskId()).getUpdateTime());
            }
        }
    }

    protected Date parseStringToDate(String day) throws ParseException {
        DateFormat format = new SimpleDateFormat("yyyy-MM-dd", Locale.ENGLISH);
        java.util.Date date = format.parse(day);
        java.sql.Date sqlDate = new java.sql.Date(date.getTime());
        return sqlDate;
    }

    protected boolean isBeforeDay(long date, Timestamp imageTaskDay) {
        return (imageTaskDay.getTime() <= date);
    }

    // FIXME is it necessaty ? "System.out.println" ?
    @Override
    public void listTasksInDB() throws SQLException, ParseException {
        List<ImageTask> allImageTask = imageStore.getAllTasks();
        for (int i = 0; i < allImageTask.size(); i++) {
            System.out.println(allImageTask.get(i).toString());
        }
    }

    @Override
    public List<Task> fillDB(
            String lowerLeftLatitude, String lowerLeftLongitude,
            String upperRightLatitude, String upperRightLongitude,
            Date initDate, Date endDate, String inputGathering, String inputPreprocessing,
            String algorithmExecution) {
        List<Task> createdTasks = new ArrayList<>();

        GregorianCalendar cal = new GregorianCalendar();
        cal.setTime(initDate);
        GregorianCalendar endCal = new GregorianCalendar();
        endCal.setTime(endDate);
        endCal.add(Calendar.DAY_OF_YEAR, 1);

        while (cal.before(endCal)) {
            try {
                int startingYear = cal.get(Calendar.YEAR);
                List<String> datasets = DatasetUtil.getSatsInOperationByYear(startingYear);

                for (String dataset : datasets) {
                    int endingYear = endCal.get(Calendar.YEAR);
                    Set<String> regions = repository.getRegionsFromArea(
                            dataset, startingYear, endingYear, lowerLeftLatitude,
                            lowerLeftLongitude, upperRightLatitude, upperRightLongitude);

                    for (String region : regions) {
                        String taskId = UUID.randomUUID().toString();

                        ImageTask iTask = getImageStore().addImageTask(
                                taskId,
                                dataset,
                                region,
                                cal.getTime(),
                                "None",
                                DEFAULT_PRIORITY,
                                inputGathering,
                                inputPreprocessing,
                                algorithmExecution
                        );

                        Task task = new Task(UUID.randomUUID().toString());
                        task.setImageTask(iTask);
                        getImageStore().addStateStamp(taskId, ImageTaskState.CREATED,
                                getImageStore().getTask(taskId).getUpdateTime());

                        createdTasks.add(task);
                    }
                }

            } catch (SQLException e) {
                LOGGER.error("Error while adding image to database", e);
            }
            cal.add(Calendar.DAY_OF_YEAR, 1);
        }
        return createdTasks;
    }

    public List<ImageTask> getTaskListInDB() throws SQLException, ParseException {
        return imageStore.getAllTasks();
    }

    @Override
    public List<Ward> getUsersToNotify() throws SQLException {
        List<Ward> wards = imageStore.getUsersToNotify();
        return wards;
    }

    public ImageTask getTaskInDB(String taskId) throws SQLException {
        List<ImageTask> allTasks = imageStore.getAllTasks();

        for (ImageTask imageTask : allTasks) {
            if (imageTask.getTaskId().equals(taskId)) {
                return imageTask;
            }
        }

        return null;
    }
    
    public List<ImageTask> getTasksInState(ImageTaskState imageState) throws SQLException {
    	return this.imageStore.getIn(imageState);
    }

    public JDBCImageDataStore getImageStore() {
        return imageStore;
    }

    public Properties getProperties() {
        return properties;
    }
}