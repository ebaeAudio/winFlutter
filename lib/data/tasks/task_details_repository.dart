import 'task_details_models.dart';

abstract interface class TaskDetailsRepository {
  Future<TaskDetails> getDetails({required String taskId});

  Future<TaskDetails> updateDetails({
    required String taskId,
    String? notes,
    String? nextStep,
    int? estimateMinutes,
    int? actualMinutes,
  });

  Future<List<TaskSubtask>> listSubtasks({required String taskId});

  Future<TaskSubtask> createSubtask({
    required String taskId,
    required String title,
  });

  Future<TaskSubtask> setSubtaskCompleted({
    required String subtaskId,
    required bool completed,
  });

  Future<void> deleteSubtask({required String subtaskId});
}


